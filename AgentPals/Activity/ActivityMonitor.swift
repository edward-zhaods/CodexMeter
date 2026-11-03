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

        return ActivitySnapshot(
            claude: anyWorking(claudeFiles, now: now, signal: ActivitySignals.claudeIsWorking),
            codex: anyWorking(codexFiles, now: now, signal: ActivitySignals.codexIsWorking),
            cursor: anyWorking(cursorFiles, now: now, signal: ActivitySignals.cursorIsWorking)
        )
    }

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
