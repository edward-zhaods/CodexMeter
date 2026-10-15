import AppKit
import Combine
import Foundation

private enum FloatingQuotaPalette {
    static let high = NSColor(
        calibratedRed: 0.59,
        green: 0.81,
        blue: 0.94,
        alpha: 1
    )
    static let medium = NSColor(
        calibratedRed: 1,
        green: 0.84,
        blue: 0.29,
        alpha: 1
    )
    static let low = NSColor(
        calibratedRed: 0.96,
        green: 0.66,
        blue: 0.76,
        alpha: 1
    )
}

enum FloatingDisplayStyle: String, CaseIterable, Identifiable {
    case detailed
    case circular

    var id: String { rawValue }

    var title: String {
        switch self {
        case .detailed:
            return "详细条"
        case .circular:
            return "圆形"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var connectionStatus: MeterConnectionStatus = .starting
    @Published private(set) var accountStatus: AccountDisplayStatus = .unknown
    @Published private(set) var fiveHourWindow: QuotaWindowViewModel?
    @Published private(set) var weeklyWindow: QuotaWindowViewModel?
    @Published private(set) var otherWindows: [QuotaWindowViewModel] = []
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var isCachedDataStale = false
    @Published private(set) var lifetimeTokenCount: Int64?
    @Published private(set) var tokenUsageDailyBuckets: [AccountTokenUsageDailyBucket] = []
    @Published private(set) var tokenUsageSummary: AccountTokenUsageSummary?
    @Published private(set) var claudeUsage: ClaudeUsageSnapshot?
    @Published private(set) var claudeScanState: ClaudeScanState = .idle
    @Published var selectedProvider: MeterProvider {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: DefaultsKeys.selectedProvider)
        }
    }
    @Published var customCodexPath: String {
        didSet {
            UserDefaults.standard.set(customCodexPath, forKey: DefaultsKeys.customCodexPath)
        }
    }
    @Published var lowQuotaNotificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(lowQuotaNotificationsEnabled, forKey: DefaultsKeys.lowQuotaNotificationsEnabled)
        }
    }
    @Published var floatingDisplayStyle: FloatingDisplayStyle {
        didSet {
            UserDefaults.standard.set(floatingDisplayStyle.rawValue, forKey: DefaultsKeys.floatingDisplayStyle)
        }
    }

    private let notificationService = NotificationService()
    private var client: CodexAppServerClient?
    private var refreshTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var notificationCancellable: AnyCancellable?
    private var lastNotificationResetKey: String?
    private var latestSnapshot: GetAccountRateLimitsResponse?
    private let claudeScanner = ClaudeUsageScanner()
    private var claudeRefreshTask: Task<Void, Never>?
    private var claudeScanInFlight = false

    init() {
        customCodexPath = UserDefaults.standard.string(forKey: DefaultsKeys.customCodexPath) ?? ""
        lowQuotaNotificationsEnabled = UserDefaults.standard.object(forKey: DefaultsKeys.lowQuotaNotificationsEnabled) as? Bool ?? true
        floatingDisplayStyle = FloatingDisplayStyle(
            rawValue: UserDefaults.standard.string(forKey: DefaultsKeys.floatingDisplayStyle) ?? ""
        ) ?? .detailed
        selectedProvider = MeterProvider(
            rawValue: UserDefaults.standard.string(forKey: DefaultsKeys.selectedProvider) ?? ""
        ) ?? .codex
        if let cachedTokenCount = UserDefaults.standard.object(
            forKey: DefaultsKeys.lifetimeTokenCount
        ) as? NSNumber {
            lifetimeTokenCount = cachedTokenCount.int64Value
        }
        restoreCachedTokenUsage()
        restoreCachedSnapshot()
        observeRateLimitUpdates()
    }

    var menuTitle: String {
        switch connectionStatus {
        case .codexNotInstalled:
            return "Codex · 未安装"
        case .unauthenticated:
            return "Codex · 未登录"
        case .offline:
            return "Codex · 离线"
        case .incompatibleVersion:
            return "Codex · 不兼容"
        case .starting:
            return "Codex · 连接中"
        case .stale:
            if let window = fiveHourWindow {
                return "Codex \(window.remainingPercentText) · 已过期"
            }
            return "Codex · 已过期"
        case .online:
            guard let window = fiveHourWindow else {
                return "Codex · 在线"
            }
            let countdown = window.resetCountdownShort ?? "重置未知"
            return "Codex 剩余 \(window.remainingPercentText) · \(countdown)"
        }
    }

    var compactMenuTitle: String {
        switch connectionStatus {
        case .online:
            return fiveHourWindow?.remainingPercentText ?? ""
        case .stale:
            return fiveHourWindow.map { "\($0.remainingPercentText) 旧" } ?? "旧"
        case .starting:
            return "..."
        case .offline:
            return "离线"
        case .codexNotInstalled:
            return "未装"
        case .unauthenticated:
            return "登录"
        case .incompatibleVersion:
            return "版本"
        }
    }

    var floatingSummaryTitle: String {
        guard let window = fiveHourWindow ?? weeklyWindow else {
            return "Codex 额度 · 同步中"
        }

        let reset = window.resetCountdownShort.map { "\($0)后重置" } ?? "重置时间未知"
        return "Codex \(window.remainingPercentText) · \(reset)"
    }

    var compactLifetimeTokenText: String {
        guard let lifetimeTokenCount else { return "已用 --" }
        let count = max(0, lifetimeTokenCount)
        let formatted = count.formatted(
            .number
                .notation(.compactName)
                .precision(.fractionLength(0...1))
        )
        return "已用 \(formatted)"
    }

    var floatingQuotaColor: NSColor {
        guard let percent = (fiveHourWindow ?? weeklyWindow)?.remainingPercent else {
            return .systemGray
        }

        if percent >= 60 {
            return FloatingQuotaPalette.high
        }
        if percent >= 30 {
            return FloatingQuotaPalette.medium
        }
        return FloatingQuotaPalette.low
    }

    var statusText: String {
        switch connectionStatus {
        case .starting:
            return "正在连接 Codex"
        case .online:
            return "运行中"
        case .stale:
            return "数据已过期"
        case .offline:
            return "离线"
        case .codexNotInstalled:
            return "未找到 Codex"
        case .unauthenticated:
            return "未登录"
        case .incompatibleVersion:
            return "协议不兼容"
        }
    }

    var statusColorName: String {
        switch connectionStatus {
        case .online:
            return "green"
        case .starting, .stale:
            return "orange"
        case .offline, .codexNotInstalled, .unauthenticated, .incompatibleVersion:
            return "red"
        }
    }

    func start() async {
        await notificationService.requestAuthorizationIfNeeded()
        startCountdownTicker()
        startClaudeRefreshLoop()
        await connectAndRefresh()
        startRefreshLoop()
    }

    func stop() {
        refreshTask?.cancel()
        countdownTask?.cancel()
        claudeRefreshTask?.cancel()
        Task {
            await client?.stop()
        }
    }

    func refreshIfNeededForPopover() {
        Task {
            await refreshClaudeUsage()
        }
        guard shouldRefreshForPopover else { return }
        Task {
            await refresh()
        }
    }

    func refresh() async {
        if client == nil {
            await connectAndRefresh()
            return
        }
        do {
            try await refreshAccountAndLimits()
        } catch CodexAppServerError.notStarted {
            markStaleOrOffline()
            await client?.stop()
            client = nil
            await connectAndRefresh()
        } catch CodexAppServerError.processExited {
            markStaleOrOffline()
            await client?.stop()
            client = nil
            await connectAndRefresh()
        } catch {
            markStaleOrOffline()
        }
    }

    func reconnect() async {
        connectionStatus = .starting
        isCachedDataStale = false
        await client?.stop()
        client = nil
        await connectAndRefresh()
    }

    func chooseCodexExecutable() {
        let panel = NSOpenPanel()
        panel.title = "选择 Codex 可执行文件"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            customCodexPath = url.path
            Task {
                await reconnect()
            }
        }
    }

    func clearCustomCodexPath() {
        customCodexPath = ""
        Task {
            await reconnect()
        }
    }

    // MARK: - Claude Code usage (local transcripts)

    var claudeStatusText: String {
        switch claudeScanState {
        case .idle:
            return "未统计"
        case .scanning:
            return "统计中"
        case .ready:
            return "已更新"
        case .failed:
            return "读取失败"
        }
    }

    var claudeStatusColorName: String {
        switch claudeScanState {
        case .ready:
            return "green"
        case .idle, .scanning:
            return "orange"
        case .failed:
            return "red"
        }
    }

    var claudeProjectsDirectoryPath: String {
        claudeScanner.projectsDirectory.path
    }

    func refreshClaudeUsage(force: Bool = false) async {
        if !force, let scannedAt = claudeUsage?.scannedAt, Date().timeIntervalSince(scannedAt) < 60 {
            return
        }
        guard !claudeScanInFlight else { return }
        claudeScanInFlight = true
        claudeScanState = .scanning
        defer { claudeScanInFlight = false }

        do {
            claudeUsage = try await claudeScanner.scan()
            claudeScanState = .ready
        } catch {
            claudeScanState = .failed(error.localizedDescription)
        }
    }

    private func startClaudeRefreshLoop() {
        claudeRefreshTask?.cancel()
        claudeRefreshTask = Task { [weak self] in
            await self?.refreshClaudeUsage(force: true)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                await self?.refreshClaudeUsage(force: true)
            }
        }
    }

    private var shouldRefreshForPopover: Bool {
        guard let lastSyncDate else { return true }
        return Date().timeIntervalSince(lastSyncDate) > 60
    }

    private func connectAndRefresh() async {
        let backoffSeconds = [1, 2, 5, 15, 30]
        for (attempt, delay) in ([0] + backoffSeconds).enumerated() {
            if attempt > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }

            do {
                try await connectOnceAndRefresh()
                return
            } catch CodexExecutableLocator.LocatorError.notFound {
                connectionStatus = .codexNotInstalled
                markCacheStaleIfPresent()
                return
            } catch CodexAppServerError.incompatibleVersion {
                connectionStatus = .incompatibleVersion
                markCacheStaleIfPresent()
                return
            } catch {
                markStaleOrOffline()
                await client?.stop()
                client = nil
            }
        }
    }

    private func connectOnceAndRefresh() async throws {
        do {
            let executableURL = try CodexExecutableLocator.findExecutable(customPath: customCodexPath)
            let newClient = CodexAppServerClient(executableURL: executableURL)
            client = newClient
            try await newClient.start()
            try await newClient.initialize()
            connectionStatus = .starting
            try await refreshAccountAndLimits()
        } catch {
            throw error
        }
    }

    private func refreshAccountAndLimits() async throws {
        guard let client else { throw CodexAppServerError.notStarted }

        let account: GetAccountResponse = try await client.request(
            method: "account/read",
            params: GetAccountParams(refreshToken: false)
        )
        accountStatus = AccountDisplayStatus(response: account)
        guard account.account != nil else {
            connectionStatus = .unauthenticated
            markCacheStaleIfPresent()
            return
        }

        let response: GetAccountRateLimitsResponse = try await client.request(
            method: "account/rateLimits/read",
            params: Optional<EmptyParams>.none
        )
        let tokenUsage: GetAccountTokenUsageResponse? = try? await client.request(
            method: "account/usage/read",
            params: Optional<EmptyParams>.none
        )
        applyRateLimits(response)
        if let tokenUsage {
            applyTokenUsage(tokenUsage)
            cacheTokenUsage(tokenUsage)
        }
        connectionStatus = .online
        isCachedDataStale = false
        lastSyncDate = Date()
        cacheSnapshot(response)
        await maybeNotifyLowQuota()
    }

    private func applyRateLimits(_ response: GetAccountRateLimitsResponse) {
        latestSnapshot = response
        let windows = QuotaWindowViewModel.windows(from: response)
        fiveHourWindow = windows.first { $0.kind == .fiveHour }
        weeklyWindow = windows.first { $0.kind == .weekly }
        otherWindows = windows.filter { $0.kind == .other }
    }

    private func markStaleOrOffline() {
        if latestSnapshot != nil {
            connectionStatus = .stale
            isCachedDataStale = true
        } else {
            connectionStatus = .offline
        }
    }

    private func markCacheStaleIfPresent() {
        if latestSnapshot != nil {
            isCachedDataStale = true
        }
    }

    private func startRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(180))
                await self?.refresh()
            }
        }
    }

    private func observeRateLimitUpdates() {
        notificationCancellable = NotificationCenter.default
            .publisher(for: .codexRateLimitsUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.refresh()
                }
            }
    }

    private func startCountdownTicker() {
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                self?.rebuildViewModelsFromCurrentSnapshot()
            }
        }
    }

    private func rebuildViewModelsFromCurrentSnapshot() {
        guard let latestSnapshot else { return }
        applyRateLimits(latestSnapshot)
    }

    private func maybeNotifyLowQuota() async {
        guard lowQuotaNotificationsEnabled, let window = fiveHourWindow else { return }
        guard window.remainingPercent <= 10 else { return }
        let resetKey = window.resetDate.map { String(Int($0.timeIntervalSince1970)) } ?? "unknown"
        guard resetKey != lastNotificationResetKey else { return }
        lastNotificationResetKey = resetKey
        await notificationService.deliverLowQuotaNotification(
            remainingPercentText: window.remainingPercentText,
            resetText: window.resetCountdownLong ?? "重置时间不可用"
        )
    }

    private func cacheSnapshot(_ response: GetAccountRateLimitsResponse) {
        guard let data = try? JSONEncoder().encode(response) else { return }
        UserDefaults.standard.set(data, forKey: DefaultsKeys.cachedSnapshot)
        UserDefaults.standard.set(Date(), forKey: DefaultsKeys.cachedSnapshotDate)
    }

    private func applyTokenUsage(_ response: GetAccountTokenUsageResponse) {
        tokenUsageSummary = response.summary
        tokenUsageDailyBuckets = (response.dailyUsageBuckets ?? [])
            .map {
                AccountTokenUsageDailyBucket(
                    startDate: $0.startDate,
                    tokens: max(0, $0.tokens)
                )
            }
            .sorted { $0.startDate < $1.startDate }

        if let tokenCount = response.summary.lifetimeTokens {
            let normalizedTokenCount = max(0, tokenCount)
            lifetimeTokenCount = normalizedTokenCount
            UserDefaults.standard.set(normalizedTokenCount, forKey: DefaultsKeys.lifetimeTokenCount)
        }
    }

    private func cacheTokenUsage(_ response: GetAccountTokenUsageResponse) {
        guard let data = try? JSONEncoder().encode(response) else { return }
        UserDefaults.standard.set(data, forKey: DefaultsKeys.cachedTokenUsage)
    }

    private func restoreCachedTokenUsage() {
        guard
            let data = UserDefaults.standard.data(forKey: DefaultsKeys.cachedTokenUsage),
            let response = try? JSONDecoder().decode(GetAccountTokenUsageResponse.self, from: data)
        else {
            return
        }
        applyTokenUsage(response)
    }

    private func restoreCachedSnapshot() {
        guard
            let data = UserDefaults.standard.data(forKey: DefaultsKeys.cachedSnapshot),
            let response = try? JSONDecoder().decode(GetAccountRateLimitsResponse.self, from: data)
        else {
            return
        }
        latestSnapshot = response
        applyRateLimits(response)
        lastSyncDate = UserDefaults.standard.object(forKey: DefaultsKeys.cachedSnapshotDate) as? Date
        isCachedDataStale = true
        connectionStatus = .stale
    }
}

extension Notification.Name {
    static let codexRateLimitsUpdated = Notification.Name("CodexRateLimitsUpdated")
}

private enum DefaultsKeys {
    static let customCodexPath = "customCodexPath"
    static let lowQuotaNotificationsEnabled = "lowQuotaNotificationsEnabled"
    static let floatingDisplayStyle = "floatingDisplayStyle"
    static let cachedSnapshot = "cachedSnapshot"
    static let cachedSnapshotDate = "cachedSnapshotDate"
    static let lifetimeTokenCount = "lifetimeTokenCount"
    static let cachedTokenUsage = "cachedTokenUsage"
    static let selectedProvider = "meterSelectedProvider"
}
