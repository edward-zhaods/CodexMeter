import Foundation

struct PetActivitySnapshot: Sendable, Equatable {
    var codexLatest: Date?
    var cursorLatest: Date?
    var geminiLatest: Date?
    var claudeLatest: Date?
    var codexPresent = false
    var cursorPresent = false
    var geminiPresent = false
    var claudePresent = false

    func latest(for kind: PetKind) -> Date? {
        switch kind {
        case .codex:
            return codexLatest
        case .cursor:
            return cursorLatest
        case .gemini:
            return geminiLatest
        case .claude:
            return claudeLatest
        }
    }

    func present(for kind: PetKind) -> Bool {
        switch kind {
        case .codex:
            return codexPresent
        case .cursor:
            return cursorPresent
        case .gemini:
            return geminiPresent
        case .claude:
            return claudePresent
        }
    }
}

enum PetActivityProbe {
    private static let skippedNames: Set<String> = [
        "Cache",
        "GPUCache",
        "Code Cache",
        "CachedData",
        "node_modules",
        "DawnGraphiteCache",
        "blob_storage"
    ]

    static func capture() -> PetActivitySnapshot {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let codex = newestFile(
            in: [
                home.appendingPathComponent(".codex/sessions"),
                home.appendingPathComponent(".codex/archived_sessions")
            ]
        )
        let cursor = newestFile(
            in: [
                home.appendingPathComponent(".cursor/projects"),
                home.appendingPathComponent(".cursor/ai-tracking")
            ]
        )
        let gemini = newestFile(
            in: [
                home.appendingPathComponent(".gemini"),
                home.appendingPathComponent(".config/gemini")
            ]
        )
        let claude = newestFile(
            in: [
                home.appendingPathComponent(".claude/projects")
            ]
        )
        return PetActivitySnapshot(
            codexLatest: codex.latest,
            cursorLatest: cursor.latest,
            geminiLatest: gemini.latest,
            claudeLatest: claude.latest,
            codexPresent: codex.present,
            cursorPresent: cursor.present,
            geminiPresent: gemini.present,
            claudePresent: claude.present
        )
    }

    private static func newestFile(in roots: [URL]) -> (present: Bool, latest: Date?) {
        let fileManager = FileManager.default
        var present = false
        var latest: Date?
        for root in roots {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory) else { continue }
            present = true
            guard isDirectory.boolValue else {
                if let date = modificationDate(of: root), latest.map({ date > $0 }) ?? true {
                    latest = date
                }
                continue
            }
            if let date = latestFileDate(in: root) {
                if let latest, date <= latest {
                    continue
                }
                latest = date
            }
        }
        return (present, latest)
    }

    private static func latestFileDate(in root: URL) -> Date? {
        let fileManager = FileManager.default
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .contentModificationDateKey]
        var latest: Date?
        var seen = 0
        var queue: [(URL, Int)] = [(root, 0)]
        while !queue.isEmpty, seen < 500 {
            let (url, depth) = queue.removeFirst()
            seen += 1
            let values = try? url.resourceValues(forKeys: keys)
            if values?.isDirectory == true {
                guard depth < 4 else { continue }
                let children = (try? fileManager.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: Array(keys),
                    options: [.skipsHiddenFiles]
                )) ?? []
                let sorted = children.sorted {
                    (modificationDate(of: $0) ?? .distantPast) > (modificationDate(of: $1) ?? .distantPast)
                }
                for child in sorted.prefix(40) where !skippedNames.contains(child.lastPathComponent) {
                    queue.append((child, depth + 1))
                }
            } else if let date = values?.contentModificationDate, latest.map({ date > $0 }) ?? true {
                latest = date
            }
        }
        return latest
    }

    private static func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
