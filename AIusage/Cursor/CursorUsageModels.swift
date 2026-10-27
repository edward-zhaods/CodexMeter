import Foundation

enum CursorSyncState: Equatable, Sendable {
    case idle
    case syncing
    case ready
    case failed(String)
}

struct CursorPlanSnapshot: Codable, Equatable, Sendable {
    var planName: String
    var periodTitle: String
    var usedPercent: Double
    var autoUsedPercent: Double
    var apiUsedPercent: Double
    var cycleStart: Date?
    var cycleEnd: Date?

    var remainingPercent: Double {
        max(0, 100 - min(max(usedPercent, 0), 100))
    }

    var autoRemainingPercent: Double {
        max(0, 100 - min(max(autoUsedPercent, 0), 100))
    }

    var apiRemainingPercent: Double {
        max(0, 100 - min(max(apiUsedPercent, 0), 100))
    }

    var remainingPercentText: String {
        "\(Int(remainingPercent.rounded()))%"
    }
}

struct CursorUsageEvent: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var timestamp: Date
    var model: String
    var input: Int64
    var output: Int64
    var cacheRead: Int64
    var cacheWrite: Int64

    var total: Int64 {
        input + output + cacheRead + cacheWrite
    }
}

struct CursorUsageSnapshot: Equatable, Sendable {
    var fetchedAt: Date
    var plan: CursorPlanSnapshot
    var events: [CursorUsageEvent]
    var historyComplete: Bool

    func events(in scope: CursorUsageScope, now: Date = Date()) -> [CursorUsageEvent] {
        switch scope {
        case .cycle:
            guard let start = plan.cycleStart, let end = plan.cycleEnd else { return events }
            return events.filter { $0.timestamp >= start && $0.timestamp < end }
        case .week:
            return events(inLastDays: 7, now: now)
        case .month:
            return events(inLastDays: 30, now: now)
        case .all:
            return events
        }
    }

    func totals(in scope: CursorUsageScope, now: Date = Date()) -> ClaudeTokenCounters {
        counters(for: events(in: scope, now: now))
    }

    func models(in scope: CursorUsageScope, now: Date = Date()) -> [ClaudeModelUsage] {
        var byModel: [String: ClaudeTokenCounters] = [:]
        for event in events(in: scope, now: now) {
            byModel[event.model, default: ClaudeTokenCounters()].add(counters(for: event))
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
                return left.displayName < right.displayName
            }
    }

    var dailyBuckets: [AccountTokenUsageDailyBucket] {
        var tokensByDay: [String: Int64] = [:]
        for event in events where event.total > 0 {
            let key = ClaudeUsageSnapshot.dayKey(for: event.timestamp)
            tokensByDay[key, default: 0] += event.total
        }
        return tokensByDay
            .map { AccountTokenUsageDailyBucket(startDate: $0.key, tokens: $0.value) }
            .sorted { $0.startDate < $1.startDate }
    }

    var activitySummary: AccountTokenUsageSummary {
        let buckets = dailyBuckets
        let activeDayKeys = buckets.filter { $0.tokens > 0 }.map(\.startDate)
        return AccountTokenUsageSummary(
            lifetimeTokens: buckets.reduce(Int64(0)) { $0 + $1.tokens },
            peakDailyTokens: buckets.map(\.tokens).max() ?? 0,
            currentStreakDays: ClaudeUsageSnapshot.currentStreak(activeDayKeys: activeDayKeys),
            longestStreakDays: ClaudeUsageSnapshot.longestStreak(activeDayKeys: activeDayKeys),
            longestRunningTurnSec: nil
        )
    }

    static func displayName(for modelID: String) -> String {
        if modelID == "default" || modelID.isEmpty {
            return "Auto"
        }
        return modelID
            .split(separator: "-")
            .map { part in
                guard let first = part.first else { return "" }
                return first.uppercased() + part.dropFirst()
            }
            .joined(separator: " ")
    }

    private func events(inLastDays dayCount: Int, now: Date) -> [CursorUsageEvent] {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) else {
            return []
        }
        return events.filter { $0.timestamp >= start && $0.timestamp <= now }
    }

    private func counters(for events: [CursorUsageEvent]) -> ClaudeTokenCounters {
        events.reduce(into: ClaudeTokenCounters()) { result, event in
            result.add(counters(for: event))
        }
    }

    private func counters(for event: CursorUsageEvent) -> ClaudeTokenCounters {
        var counters = ClaudeTokenCounters()
        counters.messages = 1
        counters.input = event.input
        counters.output = event.output
        counters.cacheRead = event.cacheRead
        counters.cacheWrite = event.cacheWrite
        return counters
    }
}

enum CursorUsageScope: String, CaseIterable, Identifiable, Sendable {
    case cycle
    case week
    case month
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cycle:
            return "本周期"
        case .week:
            return "7 天"
        case .month:
            return "30 天"
        case .all:
            return "累计"
        }
    }
}
