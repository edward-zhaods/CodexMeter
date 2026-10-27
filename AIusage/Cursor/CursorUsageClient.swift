import Foundation

/// Reads the signed-in Cursor session already stored by the Cursor app, then asks
/// Cursor for the current plan quota and token usage events.
actor CursorUsageClient {
    enum ClientError: Error, LocalizedError, Sendable {
        case cursorNotInstalled
        case notSignedIn
        case databaseUnreadable(String)
        case unauthorized
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .cursorNotInstalled:
                return "未找到 Cursor 登录数据"
            case .notSignedIn:
                return "Cursor 未登录"
            case let .databaseUnreadable(message):
                return "无法读取 Cursor 登录状态：\(message)"
            case .unauthorized:
                return "Cursor 登录已过期，请在 Cursor 里重新登录"
            case let .requestFailed(message):
                return message
            }
        }
    }

    private struct CacheFile: Codable {
        var version = 1
        var plan: CursorPlanSnapshot?
        var events: [CursorUsageEvent] = []
        var fetchedAt: Date?
        var nextPage = 1
        var historyComplete = false
    }

    private struct PeriodResponse: Decodable {
        var billingCycleStart: String?
        var billingCycleEnd: String?
        var planUsage: PlanUsage?
        var enabled: Bool?
    }

    private struct PlanUsage: Decodable {
        var totalPercentUsed: Double?
        var autoPercentUsed: Double?
        var apiPercentUsed: Double?
    }

    private struct PlanInfoResponse: Decodable {
        struct Info: Decodable {
            var planName: String?
            var includedUsagePeriod: String?
        }

        var planInfo: Info?
    }

    private struct EventsResponse: Decodable {
        var totalUsageEventsCount: Int?
        var usageEventsDisplay: [EventRow]?
    }

    private struct EventRow: Decodable {
        var timestamp: String?
        var model: String?
        var usageEventId: String?
        var tokenUsage: TokenUsage?
    }

    private struct TokenUsage: Decodable {
        var inputTokens: Int64
        var outputTokens: Int64
        var cacheReadTokens: Int64
        var cacheWriteTokens: Int64

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            inputTokens = Self.intValue(container, .inputTokens)
            outputTokens = Self.intValue(container, .outputTokens)
            cacheReadTokens = Self.intValue(container, .cacheReadTokens)
            cacheWriteTokens = Self.intValue(container, .cacheWriteTokens)
        }

        private enum CodingKeys: String, CodingKey {
            case inputTokens
            case outputTokens
            case cacheReadTokens
            case cacheWriteTokens
        }

        private static func intValue(
            _ container: KeyedDecodingContainer<CodingKeys>,
            _ key: CodingKeys
        ) -> Int64 {
            if let value = try? container.decodeIfPresent(Int64.self, forKey: key) {
                return max(0, value)
            }
            if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
                return max(0, Int64(value.rounded()))
            }
            if let value = try? container.decodeIfPresent(String.self, forKey: key),
               let number = Int64(value) {
                return max(0, number)
            }
            return 0
        }
    }

    private struct EventsQuery: Encodable {
        var startDate: Int64?
        var endDate: Int64?
        var page: Int
        var pageSize: Int
    }

    private let cacheURL: URL
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let pageSize = 100
    private let pagesPerRefresh = 8

    init(cacheURL: URL = CursorUsageClient.defaultCacheURL) {
        self.cacheURL = cacheURL
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        session = URLSession(configuration: configuration)
    }

    static var stateDatabaseURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
    }

    static var defaultCacheURL: URL {
        supportDirectory().appendingPathComponent("cursor-usage-cache.json")
    }

    static func supportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("AIusage", isDirectory: true)
    }

    func loadCachedSnapshot() -> CursorUsageSnapshot? {
        guard let cache = loadCache(), let plan = cache.plan else { return nil }
        return CursorUsageSnapshot(
            fetchedAt: cache.fetchedAt ?? .distantPast,
            plan: plan,
            events: cache.events,
            historyComplete: cache.historyComplete
        )
    }

    func refresh() async throws -> CursorUsageSnapshot {
        let token = try readAccessToken()
        let period = try await post(
            "GetCurrentPeriodUsage",
            body: EmptyBody(),
            token: token,
            as: PeriodResponse.self
        )
        let planInfo = try? await post(
            "GetPlanInfo",
            body: EmptyBody(),
            token: token,
            as: PlanInfoResponse.self
        )
        let plan = makePlan(period: period, info: planInfo)

        var cache = loadCache() ?? CacheFile()
        cache.plan = plan
        do {
            try await syncEvents(into: &cache, token: token)
        } catch {
            // Quota is still useful when the event log is temporarily unavailable.
            if cache.events.isEmpty {
                throw error
            }
        }
        cache.fetchedAt = Date()
        saveCache(cache)
        return CursorUsageSnapshot(
            fetchedAt: cache.fetchedAt ?? Date(),
            plan: plan,
            events: cache.events.sorted { $0.timestamp > $1.timestamp },
            historyComplete: cache.historyComplete
        )
    }

    private func syncEvents(into cache: inout CacheFile, token: String) async throws {
        if !cache.historyComplete {
            var pagesFetched = 0
            while pagesFetched < pagesPerRefresh {
                let response = try await post(
                    "GetFilteredUsageEvents",
                    body: EventsQuery(page: cache.nextPage, pageSize: pageSize),
                    token: token,
                    as: EventsResponse.self
                )
                let rows = response.usageEventsDisplay ?? []
                merge(rows, into: &cache)
                pagesFetched += 1
                let total = response.totalUsageEventsCount ?? cache.events.count
                if rows.count < pageSize || cache.events.count >= total {
                    cache.historyComplete = true
                    break
                }
                cache.nextPage += 1
            }
        }

        let newest = cache.events.map(\.timestamp).max()
        guard let newest else { return }
        let start = Int64((newest.timeIntervalSince1970 * 1000).rounded(.down))
        let end = Int64((Date().timeIntervalSince1970 * 1000).rounded(.up)) + 3_600_000
        var page = 1
        var pagesFetched = 0
        while pagesFetched < pagesPerRefresh {
            let response = try await post(
                "GetFilteredUsageEvents",
                body: EventsQuery(startDate: start, endDate: end, page: page, pageSize: pageSize),
                token: token,
                as: EventsResponse.self
            )
            let rows = response.usageEventsDisplay ?? []
            let inserted = merge(rows, into: &cache)
            pagesFetched += 1
            if rows.count < pageSize || inserted == 0 {
                break
            }
            page += 1
        }
    }

    @discardableResult
    private func merge(_ rows: [EventRow], into cache: inout CacheFile) -> Int {
        var known = Set(cache.events.map(\.id))
        var inserted = 0
        for (index, row) in rows.enumerated() {
            guard let event = makeEvent(row, fallbackIndex: cache.events.count + index) else { continue }
            guard known.insert(event.id).inserted else { continue }
            cache.events.append(event)
            inserted += 1
        }
        return inserted
    }

    private func makeEvent(_ row: EventRow, fallbackIndex: Int) -> CursorUsageEvent? {
        guard let timestamp = millisDate(row.timestamp) else { return nil }
        let usage = row.tokenUsage
        let model = row.model?.isEmpty == false ? row.model! : "default"
        let id = row.usageEventId?.isEmpty == false
            ? row.usageEventId!
            : "\(Int64(timestamp.timeIntervalSince1970 * 1000))-\(model)-\(fallbackIndex)"
        return CursorUsageEvent(
            id: id,
            timestamp: timestamp,
            model: model,
            input: usage?.inputTokens ?? 0,
            output: usage?.outputTokens ?? 0,
            cacheRead: usage?.cacheReadTokens ?? 0,
            cacheWrite: usage?.cacheWriteTokens ?? 0
        )
    }

    private func makePlan(period: PeriodResponse, info: PlanInfoResponse?) -> CursorPlanSnapshot {
        let usage = period.planUsage
        let start = millisDate(period.billingCycleStart)
        let end = millisDate(period.billingCycleEnd)
        return CursorPlanSnapshot(
            planName: cleanedPlanName(info?.planInfo?.planName) ?? "Cursor",
            periodTitle: periodTitle(named: info?.planInfo?.includedUsagePeriod, start: start, end: end),
            usedPercent: usage?.totalPercentUsed ?? 0,
            autoUsedPercent: usage?.autoPercentUsed ?? 0,
            apiUsedPercent: usage?.apiPercentUsed ?? 0,
            cycleStart: start,
            cycleEnd: end
        )
    }

    private func cleanedPlanName(_ name: String?) -> String? {
        guard let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func periodTitle(named raw: String?, start: Date?, end: Date?) -> String {
        let normalized = raw?.uppercased() ?? ""
        if normalized.contains("WEEK") {
            return "周额度"
        }
        if normalized.contains("MONTH") {
            return "月额度"
        }
        if normalized.contains("DAY") {
            return "日额度"
        }
        guard let start, let end else { return "额度" }
        let days = end.timeIntervalSince(start) / 86_400
        if days < 2 {
            return "日额度"
        }
        if days <= 10 {
            return "周额度"
        }
        if days <= 40 {
            return "月额度"
        }
        return "周期额度"
    }

    private func millisDate(_ raw: String?) -> Date? {
        guard let raw, let millis = Double(raw) else { return nil }
        return Date(timeIntervalSince1970: millis / 1000)
    }

    private func post<Response: Decodable, Body: Encodable>(
        _ method: String,
        body: Body,
        token: String,
        as responseType: Response.Type
    ) async throws -> Response {
        var request = URLRequest(
            url: URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/\(method)")!
        )
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ClientError.requestFailed("无法连接 Cursor")
        }
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.requestFailed("Cursor 返回了无法识别的响应")
        }
        if http.statusCode == 401 {
            throw ClientError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ClientError.requestFailed("Cursor 用量请求失败（\(http.statusCode)）")
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw ClientError.requestFailed("Cursor 用量数据无法解析")
        }
    }

    private func readAccessToken() throws -> String {
        let database = Self.stateDatabaseURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: database.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw ClientError.cursorNotInstalled
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        let encodedPath = database.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? database.path
        process.arguments = [
            "file:\(encodedPath)?mode=ro",
            "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken';"
        ]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            throw ClientError.databaseUnreadable(error.localizedDescription)
        }
        process.waitUntilExit()
        let token = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if process.terminationStatus != 0 || token.isEmpty {
            let message = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if token.isEmpty, process.terminationStatus == 0 {
                throw ClientError.notSignedIn
            }
            throw ClientError.databaseUnreadable(message.isEmpty ? "sqlite3 退出 \(process.terminationStatus)" : message)
        }
        return token
    }

    private func loadCache() -> CacheFile? {
        guard
            let data = try? Data(contentsOf: cacheURL),
            let cache = try? JSONDecoder().decode(CacheFile.self, from: data),
            cache.version == 1
        else {
            return nil
        }
        return cache
    }

    private func saveCache(_ cache: CacheFile) {
        let directory = cacheURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}

private struct EmptyBody: Encodable {}
