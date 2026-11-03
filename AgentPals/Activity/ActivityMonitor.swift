import Foundation

struct ActivitySnapshot: Equatable, Sendable {
    var claude = false
    var codex = false
    var cursor = false
}

/// Turns a transcript tail into "still working". A finished turn is idle immediately.
/// The monitor only asks when the file was written in the last 45 seconds, so a long
/// pause in the middle of a turn does not flicker back to the idle blink.
enum ActivitySignals {
    static let freshSeconds: TimeInterval = 45

    static func claudeIsWorking(tail: String) -> Bool {
        guard let last = jsonObjects(in: tail).last else { return true }
        if last["type"] as? String == "cost-state" {
            return false
        }
        if let stop = last["stop_reason"] as? String, finishedStops.contains(stop) {
            return false
        }
        if let message = last["message"] as? [String: Any],
           let stop = message["stop_reason"] as? String,
           finishedStops.contains(stop) {
            return false
        }
        return true
    }

    static func codexIsWorking(tail: String) -> Bool {
        var boundary: String?
        for object in jsonObjects(in: tail) {
            if let marker = codexMarker(in: object) {
                boundary = marker
            }
        }
        return boundary != "done"
    }

    static func cursorIsWorking(tail: String) -> Bool {
        guard let last = jsonObjects(in: tail).last else { return true }
        let type = last["type"] as? String
        let role = last["role"] as? String
        let kind = (type?.isEmpty == false ? type : nil) ?? role ?? ""
        return kind != "turn_ended"
    }

    private static let finishedStops: Set<String> = ["end_turn", "stop_sequence", "stop"]

    private static func codexMarker(in object: [String: Any]) -> String? {
        var candidates: [String] = []
        if let payload = object["payload"] as? [String: Any], let type = payload["type"] as? String {
            candidates.append(type)
        }
        if let type = object["type"] as? String {
            candidates.append(type)
        }
        for value in candidates {
            if value == "task_complete" || value == "turn_aborted" {
                return "done"
            }
            if value == "task_started"
                || value == "function_call"
                || value == "custom_tool_call"
                || value == "tool_call"
                || value == "local_shell_call"
                || value == "exec_command_begin"
                || value.contains("tool") {
                return "work"
            }
        }
        return nil
    }

    private static func jsonObjects(in tail: String) -> [[String: Any]] {
        var objects: [[String: Any]] = []
        for rawLine in tail.split(whereSeparator: \.isNewline) {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("{"), let data = line.data(using: .utf8) else { continue }
            guard let parsed = try? JSONSerialization.jsonObject(with: data),
                  let object = parsed as? [String: Any]
            else {
                continue
            }
            objects.append(object)
        }
        return objects
    }
}

/// Reads the local session files Claude Code, Codex, and Cursor already write.
/// It does not launch those tools, install hooks, or treat a running app-server as work.
final class ActivityMonitor {
    private let fileManager = FileManager.default
    private let rescanInterval: TimeInterval = 5
    private let candidateWindow: TimeInterval = 600
    private let tailBytes: UInt64 = 128 * 1024
    private var nextDirectoryScan = Date.distantPast
    private var claudeFiles: [URL] = []
    private var codexFiles: [URL] = []
    private var cursorFiles: [URL] = []

    func poll(now: Date = Date()) -> ActivitySnapshot {
        if now >= nextDirectoryScan {
            nextDirectoryScan = now.addingTimeInterval(rescanInterval)
            let cutoff = now.addingTimeInterval(-candidateWindow)
            claudeFiles = recentJSONL(under: Self.claudeProjects, newerThan: cutoff)
            codexFiles = codexRollouts(now: now, newerThan: cutoff)
            cursorFiles = cursorTranscripts(newerThan: cutoff)
        }

        composerProbe.refreshIfNeeded(now: now)
        let cursorTranscript = anyWorking(cursorFiles, now: now, signal: ActivitySignals.cursorIsWorking)
        return ActivitySnapshot(
            claude: anyWorking(claudeFiles, now: now, signal: ActivitySignals.claudeIsWorking),
            codex: anyWorking(codexFiles, now: now, signal: ActivitySignals.codexIsWorking),
            cursor: composerProbe.isGenerating || cursorTranscript
        )
    }

    private let composerProbe = CursorComposerProbe()

    private static var claudeProjects: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("projects", isDirectory: true)
    }

    private static var codexSessions: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)
    }

    private static var cursorProjects: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cursor", isDirectory: true)
            .appendingPathComponent("projects", isDirectory: true)
    }

    private func anyWorking(
        _ files: [URL],
        now: Date,
        signal: (String) -> Bool
    ) -> Bool {
        let fresh = files.compactMap { url -> (URL, Date)? in
            guard let modified = modificationDate(of: url),
                  now.timeIntervalSince(modified) <= ActivitySignals.freshSeconds
            else {
                return nil
            }
            return (url, modified)
        }
        .sorted { $0.1 > $1.1 }
        .prefix(20)

        for (url, _) in fresh {
            guard let tail = readTail(of: url) else { continue }
            if signal(tail) {
                return true
            }
        }
        return false
    }

    private func codexRollouts(now: Date, newerThan cutoff: Date) -> [URL] {
        let calendar = Calendar.current
        var files: [URL] = []
        for offset in [0, -1] {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            guard let year = parts.year, let month = parts.month, let dayNumber = parts.day else { continue }
            let folder = Self.codexSessions
                .appendingPathComponent(String(format: "%04d", year), isDirectory: true)
                .appendingPathComponent(String(format: "%02d", month), isDirectory: true)
                .appendingPathComponent(String(format: "%02d", dayNumber), isDirectory: true)
            files.append(contentsOf: recentJSONL(under: folder, newerThan: cutoff))
        }
        return files
    }

    private func cursorTranscripts(newerThan cutoff: Date) -> [URL] {
        guard let projects = try? fileManager.contentsOfDirectory(
            at: Self.cursorProjects,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for project in projects {
            let isDirectory = (try? project.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDirectory else { continue }
            let transcripts = project.appendingPathComponent("agent-transcripts", isDirectory: true)
            files.append(contentsOf: recentJSONL(under: transcripts, newerThan: cutoff))
        }
        return files
    }

    private func recentJSONL(under root: URL, newerThan cutoff: Date) -> [URL] {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }

        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey]
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var found: [URL] = []
        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if name == "node_modules" || name == ".git" {
                enumerator.skipDescendants()
                continue
            }
            guard url.pathExtension == "jsonl",
                  let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate,
                  modified >= cutoff
            else {
                continue
            }
            found.append(url)
        }
        return found
    }

    private func modificationDate(of url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    private func readTail(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        do {
            let length = try handle.seekToEnd()
            let start = length > tailBytes ? length - tailBytes : 0
            try handle.seek(toOffset: start)
            let data = try handle.readToEnd() ?? Data()
            var text = String(decoding: data, as: UTF8.self)
            if start > 0, let newline = text.firstIndex(of: "\n") {
                text = String(text[text.index(after: newline)...])
            }
            return text
        } catch {
            return nil
        }
    }
}

/// Transcript files often stay still for a whole Cursor turn. The live signal is
/// the session list's last update, or a cloud agent whose status is still running.
private final class CursorComposerProbe: @unchecked Sendable {
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "agentpals.cursor-composer", qos: .utility)
    private var inFlight = false
    private var nextRefresh = Date.distantPast
    private var generating = false

    var isGenerating: Bool {
        lock.lock()
        defer { lock.unlock() }
        return generating
    }

    func refreshIfNeeded(now: Date) {
        lock.lock()
        let shouldStart = !inFlight && now >= nextRefresh
        if shouldStart {
            inFlight = true
            nextRefresh = now.addingTimeInterval(2)
        }
        lock.unlock()
        guard shouldStart else { return }

        let database = Self.databaseURL
        queue.async { [weak self] in
            let value = Self.query(database: database, now: now)
            guard let self else { return }
            self.lock.lock()
            if let value {
                self.generating = value
            }
            self.inFlight = false
            self.lock.unlock()
        }
    }

    private static var databaseURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
    }

    /// nil means the database could not be read; the previous answer stays put.
    private static func query(database: URL, now: Date) -> Bool? {
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: database.path, isDirectory: &isDirectory),
              !isDirectory.boolValue
        else {
            return false
        }

        guard let tables = sqlite(
            database: database,
            sql: "SELECT name FROM sqlite_master WHERE type = 'table';"
        ) else {
            return nil
        }

        var report = ""
        var readSomething = false
        let header = tables.contains("composerHeaders")
            ? sqlite(database: database, sql: Self.headerSQL)
            : sqlite(database: database, sql: Self.headerBlobSQL)
        if let header {
            report += header
            if !header.hasSuffix("\n") {
                report += "\n"
            }
            readSomething = true
        }
        if let cloud = sqlite(database: database, sql: Self.cloudSQL) {
            report += cloud
            readSomething = true
        }
        guard readSomething else { return nil }
        return ActivitySignals.cursorDatabaseReportIsWorking(report, now: now)
    }

    private static let headerSQL = """
    PRAGMA busy_timeout=400;
    SELECT 'h|' || CAST(IFNULL(MAX(lastUpdatedAt), 0) AS TEXT) FROM composerHeaders;
    """

    private static let headerBlobSQL = """
    PRAGMA busy_timeout=400;
    SELECT 'j|' || replace(replace(CAST(value AS TEXT), char(10), ''), char(13), '')
    FROM ItemTable
    WHERE key = 'composer.composerHeaders';
    """

    private static let cloudSQL = """
    PRAGMA busy_timeout=400;
    SELECT 'c|' || lower(IFNULL(json_extract(agent.value, '$.status'), ''))
         || '|' || lower(IFNULL(json_extract(agent.value, '$.workflowStatus'), ''))
         || '|' || COALESCE(json_extract(agent.value, '$.updatedAt'), json_extract(agent.value, '$.lastUpdatedAt'), '')
         || '|' || CASE WHEN json_extract(agent.value, '$.archived') IN (1, 'true') THEN 1 ELSE 0 END
         || '|' || CASE WHEN json_extract(agent.value, '$.killed') IN (1, 'true') THEN 1 ELSE 0 END
    FROM ItemTable AS row, json_each(CAST(row.value AS TEXT)) AS agent
    WHERE row.key LIKE 'cloudAgentRepository.agents%'
      AND json_valid(row.value)
      AND json_type(CAST(row.value AS TEXT)) IN ('array', 'object');
    SELECT 'c|' || lower(IFNULL(json_extract(agent.value, '$.status'), ''))
         || '|' || lower(IFNULL(json_extract(agent.value, '$.workflowStatus'), ''))
         || '|' || COALESCE(json_extract(agent.value, '$.updatedAt'), json_extract(agent.value, '$.lastUpdatedAt'), '')
         || '|' || CASE WHEN json_extract(agent.value, '$.archived') IN (1, 'true') THEN 1 ELSE 0 END
         || '|' || CASE WHEN json_extract(agent.value, '$.killed') IN (1, 'true') THEN 1 ELSE 0 END
    FROM ItemTable AS row, json_each(CAST(row.value AS TEXT)) AS top, json_each(top.value) AS agent
    WHERE row.key LIKE 'cloudAgentRepository.agents%'
      AND json_valid(row.value)
      AND json_type(top.value) = 'array';
    """

    private static func sqlite(database: URL, sql: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        let encoded = database.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? database.path
        process.arguments = ["file:\(encoded)?mode=ro", sql]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}

extension ActivitySignals {
    /// Local sessions bump `composerHeaders.lastUpdatedAt` while a turn is open.
    static let cursorHeaderFreshSeconds: TimeInterval = 120
    /// A cloud agent can run much longer than a local transcript flush.
    static let cursorCloudFreshSeconds: TimeInterval = 6 * 60 * 60

    private static let cursorActiveStatuses: Set<String> = [
        "running", "creating", "active", "generating", "applying", "working",
        "waiting_for_background_work", "in_progress", "in-progress", "executing", "pending"
    ]

    static func cursorDatabaseReportIsWorking(_ report: String, now: Date) -> Bool {
        for line in report.split(separator: "\n", omittingEmptySubsequences: true) {
            let text = String(line)
            if text.hasPrefix("h|"), cursorHeaderIsLive(updatedAt: String(text.dropFirst(2)), now: now) {
                return true
            }
            if text.hasPrefix("j|"), cursorHeadersJSONIsLive(String(text.dropFirst(2)), now: now) {
                return true
            }
            if text.hasPrefix("c|") {
                let parts = text.dropFirst(2).split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                guard parts.count >= 5 else { continue }
                if cursorCloudIsLive(
                    status: parts[0],
                    workflow: parts[1],
                    updatedAt: parts[2],
                    archived: parts[3],
                    killed: parts[4],
                    now: now
                ) {
                    return true
                }
            }
        }
        return false
    }

    static func cursorHeaderIsLive(updatedAt line: String, now: Date) -> Bool {
        cursorTimestampIsRecent(line, now: now, window: cursorHeaderFreshSeconds) == true
    }

    static func cursorHeadersJSONIsLive(_ json: String, now: Date) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: #""lastUpdatedAt"\s*:\s*(\d+)"#) else {
            return false
        }
        let range = NSRange(json.startIndex..<json.endIndex, in: json)
        for match in regex.matches(in: json, range: range) {
            guard let valueRange = Range(match.range(at: 1), in: json) else { continue }
            if cursorHeaderIsLive(updatedAt: String(json[valueRange]), now: now) {
                return true
            }
        }
        return false
    }

    static func cursorCloudIsLive(
        status: String,
        workflow: String,
        updatedAt: String,
        archived: String,
        killed: String,
        now: Date
    ) -> Bool {
        if archived == "1" || killed == "1" {
            return false
        }
        let state = status.lowercased()
        let flow = workflow.lowercased()
        guard cursorActiveStatuses.contains(state) || cursorActiveStatuses.contains(flow) else {
            return false
        }
        if let recent = cursorTimestampIsRecent(updatedAt, now: now, window: cursorCloudFreshSeconds) {
            return recent
        }
        return true
    }

    /// nil when the text is not a timestamp. Numbers may be seconds or milliseconds.
    static func cursorTimestampIsRecent(_ raw: String, now: Date, window: TimeInterval) -> Bool? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "null" || trimmed == "0" {
            return nil
        }
        if let number = Double(trimmed), number > 0 {
            let seconds = number > 10_000_000_000 ? number / 1000 : number
            return now.timeIntervalSince1970 - seconds <= window
        }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: trimmed) {
            return now.timeIntervalSince(date) <= window
        }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: trimmed) {
            return now.timeIntervalSince(date) <= window
        }
        return nil
    }
}
