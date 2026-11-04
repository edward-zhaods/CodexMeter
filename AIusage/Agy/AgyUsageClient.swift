import Foundation

enum AgyUsageError: LocalizedError, Sendable {
    case notInstalled
    case versionTooOld(String)
    case commandFailed(String)
    case unreadable

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "没找到 agy"
        case .versionTooOld(let version):
            return "agy \(version) 太旧，升级到 1.1.11 后再读额度"
        case .commandFailed(let message):
            return message
        case .unreadable:
            return "agy 没有返回额度数据"
        }
    }
}

enum AgyExecutableLocator {
    static func find() throws -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "/opt/homebrew/bin/agy",
            "/usr/local/bin/agy",
            home + "/.local/bin/agy",
            home + "/bin/agy"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        if let path = loginShellPath() {
            return URL(fileURLWithPath: path)
        }
        throw AgyUsageError.notInstalled
    }

    private static func loginShellPath() -> String? {
        guard let output = try? AgyProcess.run(
            URL(fileURLWithPath: "/bin/zsh"),
            ["-lc", "command -v agy"],
            timeout: 4
        ), output.code == 0 else {
            return nil
        }
        let lines = output.stdout.split(whereSeparator: \.isNewline).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        for line in lines.reversed() where line.hasPrefix("/") && FileManager.default.isExecutableFile(atPath: line) {
            return line
        }
        return nil
    }
}

enum AgyUsageClient {
    static var cacheURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent("AIusage", isDirectory: true)
            .appendingPathComponent("agy-usage-cache.json")
    }

    static func loadCache() -> AgyUsageSnapshot? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(AgyUsageSnapshot.self, from: data)
    }

    static func saveCache(_ snapshot: AgyUsageSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return }
        let directory = cacheURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: cacheURL, options: .atomic)
    }

    /// Reads quota with `agy --print /usage`. Versions older than 1.1.11 are
    /// rejected before that command, because they can treat `/usage` as a prompt.
    static func fetch() throws -> AgyUsageSnapshot {
        let executable = try AgyExecutableLocator.find()
        if let version = installedVersion(executable), isOlder(version, than: (1, 1, 11)) {
            throw AgyUsageError.versionTooOld("\(version.0).\(version.1).\(version.2)")
        }
        let result = try AgyProcess.run(
            executable,
            ["--print", "/usage", "--output-format", "json"],
            timeout: 15
        )
        if let data = jsonData(in: result.stdout) ?? jsonData(in: result.stderr) {
            return try AgyUsageParser.parse(data)
        }
        throw AgyUsageError.commandFailed(failureMessage(result))
    }

    private static func installedVersion(_ executable: URL) -> (Int, Int, Int)? {
        guard let output = try? AgyProcess.run(executable, ["--version"], timeout: 5) else { return nil }
        return version(in: output.stdout + "\n" + output.stderr)
    }

    private static func version(in text: String) -> (Int, Int, Int)? {
        guard let range = text.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) else { return nil }
        let parts = text[range].split(separator: ".").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return (parts[0], parts[1], parts[2])
    }

    private static func isOlder(_ version: (Int, Int, Int), than minimum: (Int, Int, Int)) -> Bool {
        if version.0 != minimum.0 { return version.0 < minimum.0 }
        if version.1 != minimum.1 { return version.1 < minimum.1 }
        return version.2 < minimum.2
    }

    private static func jsonData(in text: String) -> Data? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start <= end else {
            return nil
        }
        return String(text[start...end]).data(using: .utf8)
    }

    private static func failureMessage(_ result: AgyProcess.Result) -> String {
        let blob = (result.stderr + "\n" + result.stdout).lowercased()
        if blob.contains("not logged")
            || blob.contains("sign in")
            || blob.contains("unauthorized")
            || blob.contains("unauthenticated") {
            return "agy 还没登录"
        }
        let line = result.stderr
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        if let line {
            return line.count > 60 ? String(line.prefix(60)) : line
        }
        return "agy 读取失败"
    }
}

enum AgyProcess {
    struct Result: Sendable {
        var stdout: String
        var stderr: String
        var code: Int32
    }

    static func run(_ executable: URL, _ arguments: [String], timeout: TimeInterval) throws -> Result {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            throw AgyUsageError.commandFailed("无法启动 agy")
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            let killDeadline = Date().addingTimeInterval(1)
            while process.isRunning && Date() < killDeadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            _ = stdout.fileHandleForReading.readDataToEndOfFile()
            _ = stderr.fileHandleForReading.readDataToEndOfFile()
            throw AgyUsageError.commandFailed("agy 超时")
        }

        let outText = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return Result(stdout: outText, stderr: errText, code: process.terminationStatus)
    }
}

enum AgyUsageParser {
    static func parse(_ data: Data, fetchedAt: Date = Date()) throws -> AgyUsageSnapshot {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw AgyUsageError.unreadable
        }
        guard let root = object as? [String: Any] else { throw AgyUsageError.unreadable }
        if let status = string(root["status"])?.uppercased(), status == "FAILED" || status == "ERROR" {
            throw AgyUsageError.commandFailed("agy 读取失败")
        }
        guard let rawGroups = findGroups(root), !rawGroups.isEmpty else {
            throw AgyUsageError.unreadable
        }
        let groups = rawGroups.enumerated().compactMap { index, group in
            parseGroup(group, index: index)
        }
        guard !groups.isEmpty else { throw AgyUsageError.unreadable }
        return AgyUsageSnapshot(fetchedAt: fetchedAt, groups: groups)
    }

    private static func findGroups(_ root: [String: Any]) -> [[String: Any]]? {
        if let command = root["command"] as? [String: Any],
           let data = command["data"] as? [String: Any],
           let groups = data["groups"] as? [[String: Any]],
           !groups.isEmpty {
            return groups
        }
        if let result = root["result"] as? [String: Any],
           let command = result["command"] as? [String: Any],
           let data = command["data"] as? [String: Any],
           let groups = data["groups"] as? [[String: Any]],
           !groups.isEmpty {
            return groups
        }
        if let response = root["response"] as? [String: Any],
           let groups = response["groups"] as? [[String: Any]],
           !groups.isEmpty {
            return groups
        }
        if let data = root["data"] as? [String: Any],
           let groups = data["groups"] as? [[String: Any]],
           !groups.isEmpty {
            return groups
        }
        if let groups = root["groups"] as? [[String: Any]], !groups.isEmpty {
            return groups
        }
        return nil
    }

    private static func parseGroup(_ group: [String: Any], index: Int) -> AgyQuotaGroup? {
        let rawName = string(group["displayName"])
            ?? string(group["display_name"])
            ?? string(group["name"])
            ?? "额度"
        let buckets = (group["buckets"] as? [[String: Any]] ?? []).enumerated().compactMap { offset, bucket in
            parseBucket(bucket, index: offset, group: rawName)
        }
        guard !buckets.isEmpty else { return nil }
        let id = string(group["id"]) ?? "group-\(index)-\(rawName)"
        return AgyQuotaGroup(id: id, title: friendlyGroupTitle(rawName), buckets: buckets)
    }

    private static func parseBucket(_ bucket: [String: Any], index: Int, group: String) -> AgyQuotaBucket? {
        if bool(bucket["disabled"]) { return nil }
        guard let fraction = remainingFraction(bucket) else { return nil }
        let id = string(bucket["bucketId"])
            ?? string(bucket["bucket_id"])
            ?? string(bucket["id"])
            ?? "bucket-\(index)"
        let name = string(bucket["displayName"])
            ?? string(bucket["display_name"])
            ?? string(bucket["name"])
            ?? id
        let window = string(bucket["window"])
        let kind = windowKind(window: window, id: id, name: name)
        let reset = parseDate(string(bucket["resetTime"]) ?? string(bucket["reset_time"]))
        return AgyQuotaBucket(
            id: "\(group)-\(id)",
            title: bucketTitle(kind: kind, name: name),
            windowKind: kind,
            remainingPercent: percent(from: fraction),
            resetDate: reset
        )
    }

    private static func remainingFraction(_ bucket: [String: Any]) -> Double? {
        if let value = firstNumber(bucket, keys: "remaining_fraction", "remainingFraction") {
            return value
        }
        guard let remaining = bucket["remaining"] as? [String: Any] else { return nil }
        if let value = firstNumber(remaining, keys: "remaining_fraction", "remainingFraction") {
            return value
        }
        if let kind = string(remaining["case"])?.lowercased(), kind.contains("remaining") {
            return number(remaining["value"])
        }
        return nil
    }

    private static func windowKind(window: String?, id: String, name: String) -> String {
        let blob = [window, id, name].compactMap { $0?.lowercased() }.joined(separator: " ")
        if blob.contains("week") { return "weekly" }
        if blob.contains("5h")
            || blob.contains("5-h")
            || blob.contains("5 hour")
            || blob.contains("five")
            || blob.contains("session") {
            return "fiveHour"
        }
        return "other"
    }

    private static func bucketTitle(kind: String, name: String) -> String {
        switch kind {
        case "weekly":
            return "周额度"
        case "fiveHour":
            return "5小时额度"
        default:
            return name
        }
    }

    private static func friendlyGroupTitle(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("claude") || lower.contains("gpt") {
            return "Claude / GPT"
        }
        if lower.contains("gemini") {
            if lower == "gemini" || lower == "gemini models" || lower == "gemini model" {
                return "Gemini"
            }
            return raw
        }
        return raw
    }

    private static func percent(from fraction: Double) -> Double {
        let value = fraction <= 1 ? fraction * 100 : fraction
        return min(100, max(0, value))
    }

    private static func parseDate(_ text: String?) -> Date? {
        guard let text else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: text) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: text)
    }

    private static func firstNumber(_ object: [String: Any], keys: String...) -> Double? {
        for key in keys {
            if let value = number(object[key]) {
                return value
            }
        }
        return nil
    }

    private static func number(_ raw: Any?) -> Double? {
        if raw == nil || raw is NSNull { return nil }
        if let value = raw as? Double { return value }
        if let value = raw as? Int { return Double(value) }
        if let value = raw as? NSNumber { return value.doubleValue }
        if let text = raw as? String { return Double(text) }
        return nil
    }

    private static func string(_ raw: Any?) -> String? {
        guard let text = raw as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func bool(_ raw: Any?) -> Bool {
        if raw is NSNull { return false }
        if let value = raw as? Bool { return value }
        if let value = raw as? NSNumber { return value.boolValue }
        return false
    }
}
