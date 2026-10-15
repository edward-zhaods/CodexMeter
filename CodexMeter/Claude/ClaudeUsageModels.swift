import Foundation

func compactTokenText(_ value: Int64) -> String {
    max(0, value).formatted(
        .number
            .notation(.compactName)
            .precision(.fractionLength(0...1))
    )
}

enum MeterProvider: String, CaseIterable, Identifiable, Sendable {
    case codex
    case claude

    var id: String { rawValue }

    var title: String {
        switch self {
        case .codex:
            return "Codex"
        case .claude:
            return "Claude"
        }
    }
}

struct ClaudeTokenCounters: Codable, Sendable, Equatable {
    var messages: Int64 = 0
    var input: Int64 = 0
    var output: Int64 = 0
    var cacheWrite: Int64 = 0
    var cacheRead: Int64 = 0

    var total: Int64 {
        input + output + cacheWrite + cacheRead
    }

    mutating func add(_ other: ClaudeTokenCounters) {
        messages += other.messages
        input += other.input
        output += other.output
        cacheWrite += other.cacheWrite
        cacheRead += other.cacheRead
    }
}

/// Day key ("yyyy-MM-dd" in the local calendar) → model id → counters.
typealias ClaudeDailyModelUsage = [String: [String: ClaudeTokenCounters]]

/// One API response found in a transcript. Encoded as a compact JSON array in the cache.
struct ClaudeMessageRecord: Codable, Sendable, Equatable {
    let id: String
    let dayKey: String
    let model: String
    let counters: ClaudeTokenCounters

    init(id: String, dayKey: String, model: String, counters: ClaudeTokenCounters) {
        self.id = id
        self.dayKey = dayKey
        self.model = model
        self.counters = counters
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        id = try container.decode(String.self)
        dayKey = try container.decode(String.self)
        model = try container.decode(String.self)
        var counters = ClaudeTokenCounters()
        counters.messages = try container.decode(Int64.self)
        counters.input = try container.decode(Int64.self)
        counters.output = try container.decode(Int64.self)
        counters.cacheWrite = try container.decode(Int64.self)
        counters.cacheRead = try container.decode(Int64.self)
        self.counters = counters
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(id)
        try container.encode(dayKey)
        try container.encode(model)
        try container.encode(counters.messages)
        try container.encode(counters.input)
        try container.encode(counters.output)
        try container.encode(counters.cacheWrite)
        try container.encode(counters.cacheRead)
    }
}

struct ClaudeTranscriptRecord: Codable, Sendable {
    let size: Int64
    let modifiedAt: TimeInterval
    let messages: [ClaudeMessageRecord]
}

struct ClaudeUsageCache: Codable, Sendable {
    static let currentVersion = 2

    var version = ClaudeUsageCache.currentVersion
    var files: [String: ClaudeTranscriptRecord] = [:]
}

enum ClaudeUsageScope: String, CaseIterable, Identifiable, Sendable {
    case today
    case week
    case month
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:
            return "今日"
        case .week:
            return "7 天"
        case .month:
            return "30 天"
        case .all:
            return "累计"
        }
    }

    var dayCount: Int? {
        switch self {
        case .today:
            return 1
        case .week:
            return 7
        case .month:
            return 30
        case .all:
            return nil
        }
    }
}

struct ClaudeModelUsage: Identifiable, Sendable, Equatable {
    let modelID: String
    let displayName: String
    let counters: ClaudeTokenCounters

    var id: String { modelID }
}

enum ClaudeScanState: Equatable, Sendable {
    case idle
    case scanning
    case ready
    case failed(String)
}

struct ClaudeUsageSnapshot: Sendable, Equatable {
    let scannedAt: Date
    let transcriptCount: Int
    let sessionCount: Int
    let daily: ClaudeDailyModelUsage

    var earliestDayKey: String? {
        daily.keys.min()
    }

    func totals(in scope: ClaudeUsageScope, now: Date = Date()) -> ClaudeTokenCounters {
        var result = ClaudeTokenCounters()
        for key in dayKeys(in: scope, now: now) {
            guard let models = daily[key] else { continue }
            for counters in models.values {
                result.add(counters)
            }
        }
        return result
    }

    func models(in scope: ClaudeUsageScope, now: Date = Date()) -> [ClaudeModelUsage] {
        var byModel: [String: ClaudeTokenCounters] = [:]
        for key in dayKeys(in: scope, now: now) {
            guard let models = daily[key] else { continue }
            for (modelID, counters) in models {
                byModel[modelID, default: ClaudeTokenCounters()].add(counters)
            }
        }

        return byModel
            .map { modelID, counters in
                ClaudeModelUsage(
                    modelID: modelID,
                    displayName: Self.displayName(for: modelID),
                    counters: counters
                )
            }
            .sorted { left, right in
                if left.counters.total != right.counters.total {
                    return left.counters.total > right.counters.total
                }
                return left.modelID < right.modelID
            }
    }

    var dailyBuckets: [AccountTokenUsageDailyBucket] {
        daily
            .map { key, models in
                AccountTokenUsageDailyBucket(
                    startDate: key,
                    tokens: models.values.reduce(Int64(0)) { $0 + $1.total }
                )
            }
            .sorted { $0.startDate < $1.startDate }
    }

    var activitySummary: AccountTokenUsageSummary {
        let buckets = dailyBuckets
        let activeDayKeys = buckets.filter { $0.tokens > 0 }.map(\.startDate)
        return AccountTokenUsageSummary(
            lifetimeTokens: buckets.reduce(Int64(0)) { $0 + $1.tokens },
            peakDailyTokens: buckets.map(\.tokens).max() ?? 0,
            currentStreakDays: Self.currentStreak(activeDayKeys: activeDayKeys),
            longestStreakDays: Self.longestStreak(activeDayKeys: activeDayKeys),
            longestRunningTurnSec: nil
        )
    }

    static func currentStreak(
        activeDayKeys: [String],
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int64 {
        let active = Set(activeDayKeys)
        var cursor = calendar.startOfDay(for: now)
        if !active.contains(dayKey(for: cursor, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        var streak: Int64 = 0
        while active.contains(dayKey(for: cursor, calendar: calendar)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    static func longestStreak(
        activeDayKeys: [String],
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int64 {
        let dates = activeDayKeys
            .compactMap { date(fromDayKey: $0, calendar: calendar) }
            .sorted()
        var longest: Int64 = 0
        var current: Int64 = 0
        var previous: Date?

        for date in dates {
            if let previous,
               let next = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(next, inSameDayAs: date) {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            previous = date
        }
        return longest
    }

    static func dayKey(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func date(fromDayKey key: String, calendar: Calendar = .autoupdatingCurrent) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// "claude-fable-5-1" → "Fable 5.1", "claude-3-5-sonnet-20241022" → "Sonnet 3.5".
    static func displayName(for modelID: String) -> String {
        var tokens = modelID.split(separator: "-").map(String.init)
        if tokens.first?.lowercased() == "claude" {
            tokens.removeFirst()
        }

        var family: [String] = []
        var version: [String] = []
        for token in tokens {
            if token.allSatisfy(\.isNumber) {
                if token.count >= 8 {
                    break
                }
                version.append(token)
            } else {
                family.append(token.prefix(1).uppercased() + token.dropFirst())
            }
        }

        let name = (family + [version.joined(separator: ".")])
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? modelID : name
    }

    private func dayKeys(in scope: ClaudeUsageScope, now: Date) -> [String] {
        guard let dayCount = scope.dayCount else {
            return Array(daily.keys)
        }

        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) else {
            return []
        }
        let lower = Self.dayKey(for: start, calendar: calendar)
        let upper = Self.dayKey(for: today, calendar: calendar)
        return daily.keys.filter { $0 >= lower && $0 <= upper }
    }
}
