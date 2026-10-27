import Foundation

enum CodexAppServerError: Error, LocalizedError {
    case notStarted
    case processExited
    case invalidMessage
    case responseMissingResult
    case incompatibleVersion
    case rpcError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .notStarted:
            return "Codex app-server has not started."
        case .processExited:
            return "Codex app-server exited."
        case .invalidMessage:
            return "Invalid JSON-RPC message."
        case .responseMissingResult:
            return "JSON-RPC response did not include a result."
        case .incompatibleVersion:
            return "Codex app-server protocol is incompatible."
        case let .rpcError(code, message):
            return "JSON-RPC error \(code): \(message)"
        }
    }
}

actor CodexAppServerClient {
    private let executableURL: URL
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var nextRequestID = 1
    private var pendingRequests: [Int: CheckedContinuation<Data, Error>] = [:]
    private var stdoutBuffer = Data()
    private var stderrBuffer = Data()

    init(executableURL: URL) {
        self.executableURL = executableURL
    }

    func start() async throws {
        if process?.isRunning == true { return }

        let process = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = executableURL
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        process.terminationHandler = { [weak process] _ in
            guard process != nil else { return }
            Task {
                await self.failAllPending(CodexAppServerError.processExited)
            }
        }

        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task {
                await self.handleStdout(data)
            }
        }

        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task {
                await self.handleStderr(data)
            }
        }

        try process.run()
        self.process = process
        self.stdinHandle = stdin.fileHandleForWriting
    }

    func initialize() async throws {
        let params = InitializeParams(
            clientInfo: ClientInfo(
                name: "codex_meter",
                title: "Codex Meter",
                version: "0.1.0"
            ),
            capabilities: nil
        )
        let _: EmptyDecodable = try await request(method: "initialize", params: params)
        try writeNotification(method: "initialized")
    }

    func request<Result: Decodable, Params: Encodable>(method: String, params: Params?) async throws -> Result {
        guard process?.isRunning == true, let stdinHandle else {
            throw CodexAppServerError.notStarted
        }

        let requestID = nextRequestID
        nextRequestID += 1

        var payload: [String: Any] = [
            "id": requestID,
            "method": method
        ]
        if let params {
            let data = try JSONEncoder().encode(params)
            let object = try JSONSerialization.jsonObject(with: data)
            payload["params"] = object
        }

        let data = try JSONSerialization.data(withJSONObject: payload)
        let line = data + Data([0x0A])

        let responseData = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            pendingRequests[requestID] = continuation
            do {
                try stdinHandle.write(contentsOf: line)
            } catch {
                pendingRequests.removeValue(forKey: requestID)
                continuation.resume(throwing: error)
            }
        }
        return try JSONDecoder().decode(Result.self, from: responseData)
    }

    func stop() {
        process?.standardOutput = nil
        process?.standardError = nil
        process?.terminate()
        process = nil
        stdinHandle = nil
        failAllPending(CodexAppServerError.processExited)
    }

    private func writeNotification(method: String) throws {
        guard let stdinHandle else { throw CodexAppServerError.notStarted }
        let payload: [String: Any] = [
            "method": method
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        try stdinHandle.write(contentsOf: data + Data([0x0A]))
    }

    private func handleStdout(_ data: Data) async {
        stdoutBuffer.append(data)
        while let newlineRange = stdoutBuffer.firstRange(of: Data([0x0A])) {
            let line = stdoutBuffer.subdata(in: stdoutBuffer.startIndex..<newlineRange.lowerBound)
            stdoutBuffer.removeSubrange(stdoutBuffer.startIndex...newlineRange.lowerBound)
            guard !line.isEmpty else { continue }
            handleLine(line)
        }
    }

    private func handleStderr(_ data: Data) {
        stderrBuffer.append(data)
        if stderrBuffer.count > 16_384 {
            stderrBuffer.removeFirst(stderrBuffer.count - 16_384)
        }
    }

    private func handleLine(_ line: Data) {
        guard
            let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any]
        else {
            return
        }

        if let id = object["id"] as? Int {
            completeRequest(id: id, object: object)
            return
        }

        if object["method"] as? String == "account/rateLimits/updated" {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .codexRateLimitsUpdated, object: nil)
            }
            return
        }
    }

    private func completeRequest(id: Int, object: [String: Any]) {
        guard let continuation = pendingRequests.removeValue(forKey: id) else { return }

        if let error = object["error"] as? [String: Any] {
            let code = error["code"] as? Int ?? -1
            let message = error["message"] as? String ?? "Unknown error"
            continuation.resume(throwing: CodexAppServerError.rpcError(code: code, message: message))
            return
        }

        guard let result = object["result"] else {
            continuation.resume(throwing: CodexAppServerError.responseMissingResult)
            return
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: result)
            continuation.resume(returning: data)
        } catch {
            continuation.resume(throwing: error)
        }
    }

    private func failAllPending(_ error: Error) {
        let continuations = pendingRequests.values
        pendingRequests.removeAll()
        for continuation in continuations {
            continuation.resume(throwing: error)
        }
    }
}

private struct InitializeParams: Encodable {
    let clientInfo: ClientInfo
    let capabilities: InitializeCapabilities?
}

private struct ClientInfo: Encodable {
    let name: String
    let title: String
    let version: String
}

private struct InitializeCapabilities: Encodable {}
