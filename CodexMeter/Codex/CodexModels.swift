import Foundation

struct EmptyParams: Encodable {}

struct EmptyDecodable: Decodable {
    init() {}
    init(from decoder: Decoder) throws {}
}

struct GetAccountParams: Encodable {
    let refreshToken: Bool
}

struct GetAccountResponse: Decodable {
    let account: Account?
    let requiresOpenaiAuth: Bool
}

struct Account: Decodable {
    let planType: String?
    let authMode: String?
}

struct GetAccountRateLimitsResponse: Codable {
    let rateLimits: RateLimitSnapshot
    let rateLimitsByLimitId: [String: RateLimitSnapshot]?
    let rateLimitResetCredits: RateLimitResetCreditsSummary?
}

struct GetAccountTokenUsageResponse: Decodable {
    let summary: AccountTokenUsageSummary
}

struct AccountTokenUsageSummary: Decodable {
    let lifetimeTokens: Int64?
}

struct RateLimitResetCreditsSummary: Codable {
    let credits: [RateLimitResetCredit]?
}

struct RateLimitResetCredit: Codable {
    let id: String?
    let expiresAt: Double?
}

struct RateLimitSnapshot: Codable {
    let limitId: String?
    let limitName: String?
    let primary: RateLimitWindow?
    let secondary: RateLimitWindow?
    let credits: CreditsSnapshot?
    let individualLimit: SpendControlLimitSnapshot?
    let spendControlReached: Bool?
    let planType: String?
    let rateLimitReachedType: String?
}

struct CreditsSnapshot: Codable {
    let remaining: Double?
    let total: Double?
}

struct SpendControlLimitSnapshot: Codable {
    let usedPercent: Double?
}

struct RateLimitWindow: Codable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: Double?
}

enum MeterConnectionStatus {
    case starting
    case online
    case stale
    case offline
    case codexNotInstalled
    case unauthenticated
    case incompatibleVersion
}

enum AccountDisplayStatus {
    case unknown
    case signedIn
    case requiresOpenAIAuth

    init(response: GetAccountResponse) {
        if response.account == nil {
            self = .requiresOpenAIAuth
        } else {
            self = .signedIn
        }
    }
}

enum QuotaWindowKind {
    case fiveHour
    case weekly
    case other
}

struct QuotaWindowViewModel: Identifiable {
    let id: String
    let kind: QuotaWindowKind
    let title: String
    let usedPercent: Double
    let remainingPercent: Double
    let resetDate: Date?
    let windowDurationMins: Int?

    var usedPercentText: String {
        "\(Int(usedPercent.rounded()))%"
    }

    var remainingPercentText: String {
        "\(Int(remainingPercent.rounded()))%"
    }

    var resetCountdownShort: String? {
        guard let resetDate else { return nil }
        return CountdownFormatter.shortString(until: resetDate)
    }

    var resetCountdownLong: String? {
        guard let resetDate else { return nil }
        return "重置于 \(CountdownFormatter.longString(until: resetDate))"
    }

    var resetLineText: String {
        resetCountdownShort.map { "\($0)后重置" } ?? "重置时间未知"
    }

    var healthLevel: QuotaHealthLevel {
        if remainingPercent >= 66 {
            return .good
        }
        if remainingPercent >= 33 {
            return .warning
        }
        return .danger
    }

    static func windows(from response: GetAccountRateLimitsResponse) -> [QuotaWindowViewModel] {
        let snapshot = response.rateLimitsByLimitId?["codex"] ?? response.rateLimits
        var windows: [QuotaWindowViewModel] = []

        if let primary = snapshot.primary {
            windows.append(makeWindow(source: primary, suffix: "primary"))
        }
        if let secondary = snapshot.secondary {
            windows.append(makeWindow(source: secondary, suffix: "secondary"))
        }

        return windows.sorted { left, right in
            sortRank(left.kind) < sortRank(right.kind)
        }
    }

    private static func makeWindow(source: RateLimitWindow, suffix: String) -> QuotaWindowViewModel {
        let kind = kind(for: source.windowDurationMins)
        let duration = source.windowDurationMins
        let title: String
        switch kind {
        case .fiveHour:
            title = "5 小时额度"
        case .weekly:
            title = "周额度"
        case .other:
            title = dynamicTitle(for: duration)
        }

        let used = min(max(source.usedPercent, 0), 100)
        let remaining = max(0, 100 - used)
        let resetDate = source.resetsAt.map { Date(timeIntervalSince1970: $0) }

        return QuotaWindowViewModel(
            id: "\(duration.map(String.init) ?? "unknown")-\(suffix)",
            kind: kind,
            title: title,
            usedPercent: used,
            remainingPercent: remaining,
            resetDate: resetDate,
            windowDurationMins: duration
        )
    }

    private static func kind(for duration: Int?) -> QuotaWindowKind {
        switch duration {
        case 300:
            return .fiveHour
        case 10080:
            return .weekly
        default:
            return .other
        }
    }

    private static func dynamicTitle(for duration: Int?) -> String {
        guard let duration else { return "额度窗口" }
        if duration >= 60, duration % 60 == 0 {
            return "\(duration / 60) 小时额度"
        }
        return "\(duration) 分钟额度"
    }

    private static func sortRank(_ kind: QuotaWindowKind) -> Int {
        switch kind {
        case .fiveHour:
            return 0
        case .weekly:
            return 1
        case .other:
            return 2
        }
    }
}

enum QuotaHealthLevel {
    case good
    case warning
    case danger
}
