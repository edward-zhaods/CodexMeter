import Foundation

/// Aggregates Claude Code token usage from the local transcripts in `~/.claude/projects`.
///
/// Every assistant record in a transcript carries the model id and the API usage of
/// that response. Files are parsed once and cached by size + modification time, so a
/// refresh only re-reads transcripts that changed since the last scan.
///
/// A response can show up more than once: a multi-block reply is written as several
/// lines sharing one message id, and resumed or forked sessions copy the earlier
/// history into a new transcript file. Responses are therefore de-duplicated by
/// message id across all files, keeping the copy with the largest output count
/// (an early streaming snapshot carries a smaller, partial usage).
actor ClaudeUsageScanner {
    enum ScannerError: Error, LocalizedError {
        case projectsDirectoryMissing(String)
        case enumerationFailed(String)

        var errorDescription: String? {
            switch self {
            case let .projectsDirectoryMissing(path):
                return "未找到 Claude 会话目录：\(path)"
            case let .enumerationFailed(path):
                return "无法读取 Claude 会话目录：\(path)"
            }
        }
    }

    static var defaultProjectsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("projects", isDirectory: true)
    }

    static var defaultCacheURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent("AIusage", isDirectory: true)
            .appendingPathComponent("claude-usage-cache.json")
    }

    let projectsDirectory: URL

    private let cacheURL: URL
    private let calendar = Calendar.autoupdatingCurrent
    private let isoFormatter: ISO8601DateFormatter
    private let isoFallbackFormatter: ISO8601DateFormatter
    private let assistantNeedle = Array("\"type\":\"assistant\"".utf8)
    private let usageNeedle = Array("\"usage\"".utf8)
    private var cache: ClaudeUsageCache?

    init(
        projectsDirectory: URL = ClaudeUsageScanner.defaultProjectsDirectory,
        cacheURL: URL = ClaudeUsageScanner.defaultCacheURL
    ) {
        self.projectsDirectory = projectsDirectory
        self.cacheURL = cacheURL

        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        isoFormatter = withFraction

        let withoutFraction = ISO8601DateFormatter()
        withoutFraction.formatOptions = [.withInternetDateTime]
        isoFallbackFormatter = withoutFraction
    }

    func scan() throws -> ClaudeUsageSnapshot {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard
            fileManager.fileExists(atPath: projectsDirectory.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            throw ScannerError.projectsDirectoryMissing(projectsDirectory.path)
        }

        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = fileManager.enumerator(
            at: projectsDirectory,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ) else {
            throw ScannerError.enumerationFailed(projectsDirectory.path)
        }

        var cache = loadCache()
        var files: [String: ClaudeTranscriptRecord] = [:]
        var transcriptCount = 0
        var sessionCount = 0

        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            guard
                let values = try? url.resourceValues(forKeys: Set(keys)),
                values.isRegularFile == true
            else {
                continue
            }

            let size = Int64(values.fileSize ?? 0)
            let modifiedAt = values.contentModificationDate?.timeIntervalSince1970 ?? 0
            let path = url.path
            let record: ClaudeTranscriptRecord
            if let cached = cache.files[path], cached.size == size, cached.modifiedAt == modifiedAt {
                record = cached
            } else {
                record = ClaudeTranscriptRecord(
                    size: size,
                    modifiedAt: modifiedAt,
                    messages: parseTranscript(at: url, fallbackDate: values.contentModificationDate ?? Date())
                )
            }

            files[path] = record
            transcriptCount += 1
            if !path.contains("/subagents/") {
                sessionCount += 1
            }
        }

        cache.files = files
        self.cache = cache
        saveCache(cache)

        return ClaudeUsageSnapshot(
            scannedAt: Date(),
            transcriptCount: transcriptCount,
            sessionCount: sessionCount,
            daily: Self.aggregate(files)
        )
    }

    /// Merges per-file records into day → model → counters, counting each message id once.
    static func aggregate(_ files: [String: ClaudeTranscriptRecord]) -> ClaudeDailyModelUsage {
        var best: [String: ClaudeMessageRecord] = [:]
        var anonymous: [ClaudeMessageRecord] = []

        for path in files.keys.sorted() {
            guard let record = files[path] else { continue }
            for message in record.messages {
                if message.id.isEmpty {
                    anonymous.append(message)
                } else if let existing = best[message.id] {
                    if message.counters.output > existing.counters.output {
                        best[message.id] = message
                    }
                } else {
                    best[message.id] = message
                }
            }
        }

        var daily: ClaudeDailyModelUsage = [:]
        for message in best.values {
            daily[message.dayKey, default: [:]][message.model, default: ClaudeTokenCounters()].add(message.counters)
        }
        for message in anonymous {
            daily[message.dayKey, default: [:]][message.model, default: ClaudeTokenCounters()].add(message.counters)
        }
        return daily
    }

    // MARK: - Transcript parsing

    private func parseTranscript(at url: URL, fallbackDate: Date) -> [ClaudeMessageRecord] {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return [] }

        var order: [String] = []
        var byID: [String: ClaudeMessageRecord] = [:]
        var anonymous: [ClaudeMessageRecord] = []

        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard let base = buffer.baseAddress else { return }
            let total = buffer.count
            var offset = 0

            while offset < total {
                let lineStart = base + offset
                let remaining = total - offset
                let lineLength: Int
                if let newline = memchr(lineStart, 0x0A, remaining) {
                    lineLength = lineStart.distance(to: UnsafeRawPointer(newline))
                } else {
                    lineLength = remaining
                }
                offset += lineLength + 1

                guard
                    lineLength > 64,
                    contains(lineStart, lineLength, assistantNeedle),
                    contains(lineStart, lineLength, usageNeedle)
                else {
                    continue
                }

                let line = Data(bytes: lineStart, count: lineLength)
                guard let message = parseAssistantLine(line, fallbackDate: fallbackDate) else { continue }

                if message.id.isEmpty {
                    anonymous.append(message)
                } else if let existing = byID[message.id] {
                    if message.counters.output > existing.counters.output {
                        byID[message.id] = message
                    }
                } else {
                    byID[message.id] = message
                    order.append(message.id)
                }
            }
        }

        return order.compactMap { byID[$0] } + anonymous
    }

    private func contains(_ base: UnsafeRawPointer, _ length: Int, _ needle: [UInt8]) -> Bool {
        needle.withUnsafeBytes { needleBuffer in
            guard let needleBase = needleBuffer.baseAddress else { return false }
            return memmem(base, length, needleBase, needleBuffer.count) != nil
        }
    }

    private func parseAssistantLine(_ line: Data, fallbackDate: Date) -> ClaudeMessageRecord? {
        guard
            let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
            object["type"] as? String == "assistant",
            let message = object["message"] as? [String: Any],
            let model = message["model"] as? String,
            !model.isEmpty,
            !model.hasPrefix("<"),
            let usage = message["usage"] as? [String: Any]
        else {
            return nil
        }

        var counters = ClaudeTokenCounters()
        counters.messages = 1
        counters.input = tokenValue(usage["input_tokens"])
        counters.output = tokenValue(usage["output_tokens"])
        counters.cacheWrite = tokenValue(usage["cache_creation_input_tokens"])
        counters.cacheRead = tokenValue(usage["cache_read_input_tokens"])

        let date = (object["timestamp"] as? String).flatMap(parseTimestamp) ?? fallbackDate
        return ClaudeMessageRecord(
            id: (message["id"] as? String) ?? "",
            dayKey: ClaudeUsageSnapshot.dayKey(for: date, calendar: calendar),
            model: model,
            counters: counters
        )
    }

    private func tokenValue(_ value: Any?) -> Int64 {
        guard let number = value as? NSNumber else { return 0 }
        return max(0, number.int64Value)
    }

    private func parseTimestamp(_ text: String) -> Date? {
        isoFormatter.date(from: text) ?? isoFallbackFormatter.date(from: text)
    }

    // MARK: - Cache

    private func loadCache() -> ClaudeUsageCache {
        if let cache {
            return cache
        }
        guard
            let data = try? Data(contentsOf: cacheURL),
            let decoded = try? JSONDecoder().decode(ClaudeUsageCache.self, from: data),
            decoded.version == ClaudeUsageCache.currentVersion
        else {
            return ClaudeUsageCache()
        }
        return decoded
    }

    private func saveCache(_ cache: ClaudeUsageCache) {
        let directory = cacheURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
