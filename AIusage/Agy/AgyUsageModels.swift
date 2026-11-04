import Foundation

enum AgySyncState: Equatable, Sendable {
    case idle
    case syncing
    case ready
    case failed(String)
}

struct AgyUsageSnapshot: Codable, Equatable, Sendable {
    var fetchedAt: Date
    var groups: [AgyQuotaGroup]

    var headline: AgyQuotaBucket? {
        groups
            .flatMap(\.buckets)
            .min { lhs, rhs in
                if lhs.remainingPercent != rhs.remainingPercent {
                    return lhs.remainingPercent < rhs.remainingPercent
                }
                let left = lhs.resetDate ?? .distantFuture
                let right = rhs.resetDate ?? .distantFuture
                return left < right
            }
    }

    var headlineGroupTitle: String {
        guard let headline else { return "Agy" }
        return groups.first { group in
            group.buckets.contains { $0.id == headline.id }
        }?.title ?? "Agy"
    }
}

struct AgyQuotaGroup: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var title: String
    var buckets: [AgyQuotaBucket]
}

struct AgyQuotaBucket: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var title: String
    /// "weekly", "fiveHour", or "other".
    var windowKind: String
    var remainingPercent: Double
    var resetDate: Date?

    var quotaKind: QuotaWindowKind {
        switch windowKind {
        case "weekly":
            return .weekly
        case "fiveHour":
            return .fiveHour
        default:
            return .other
        }
    }

    var window: QuotaWindowViewModel {
        let remaining = min(100, max(0, remainingPercent))
        return QuotaWindowViewModel(
            id: id,
            kind: quotaKind,
            title: title,
            usedPercent: min(100, max(0, 100 - remaining)),
            remainingPercent: remaining,
            resetDate: resetDate,
            windowDurationMins: windowKind == "weekly" ? 10_080 : (windowKind == "fiveHour" ? 300 : nil)
        )
    }
}

extension AgyUsageSnapshot {
    /// Gemini pools inside the same agy snapshot. No second CLI call.
    var geminiGroups: [AgyQuotaGroup] {
        groups.compactMap { group in
            if group.mentionsGemini {
                return group
            }
            let buckets = group.buckets.filter { $0.mentionsGemini }
            guard !buckets.isEmpty else { return nil }
            return AgyQuotaGroup(id: "\(group.id)-gemini", title: "Gemini", buckets: buckets)
        }
    }

    func tightest(in groups: [AgyQuotaGroup]) -> (groupTitle: String, bucket: AgyQuotaBucket)? {
        let pairs = groups.flatMap { group in
            group.buckets.map { (groupTitle: group.title, bucket: $0) }
        }
        return pairs.min { lhs, rhs in
            if lhs.bucket.remainingPercent != rhs.bucket.remainingPercent {
                return lhs.bucket.remainingPercent < rhs.bucket.remainingPercent
            }
            let left = lhs.bucket.resetDate ?? .distantFuture
            let right = rhs.bucket.resetDate ?? .distantFuture
            return left < right
        }
    }
}

private extension AgyQuotaGroup {
    var mentionsGemini: Bool {
        title.range(of: "gemini", options: .caseInsensitive) != nil
            || id.range(of: "gemini", options: .caseInsensitive) != nil
    }
}

private extension AgyQuotaBucket {
    var mentionsGemini: Bool {
        id.range(of: "gemini", options: .caseInsensitive) != nil
            || title.range(of: "gemini", options: .caseInsensitive) != nil
    }
}
