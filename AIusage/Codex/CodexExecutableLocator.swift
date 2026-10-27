import Foundation

enum CodexExecutableLocator {
    enum LocatorError: Error {
        case notFound
    }

    static func findExecutable(customPath: String) throws -> URL {
        let trimmedPath = customPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPath.isEmpty, isExecutable(at: trimmedPath) {
            return URL(fileURLWithPath: trimmedPath)
        }

        let candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ]

        for path in candidates where isExecutable(at: path) {
            return URL(fileURLWithPath: path)
        }

        if let path = findInLoginShellPath() {
            return URL(fileURLWithPath: path)
        }

        throw LocatorError.notFound
    }

    private static func isExecutable(at path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }

    private static func findInLoginShellPath() -> String? {
        let shellURL = URL(fileURLWithPath: "/bin/zsh")
        let process = Process()
        let output = Pipe()
        process.executableURL = shellURL
        process.arguments = ["-lc", "command -v codex"]
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let path, !path.isEmpty, isExecutable(at: path) else { return nil }
        return path
    }
}
