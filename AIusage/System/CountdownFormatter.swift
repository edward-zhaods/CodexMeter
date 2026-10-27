import Foundation

enum CountdownFormatter {
    static func shortString(until date: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let days = seconds / 86_400
        let hoursAfterDays = (seconds % 86_400) / 3600
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if days > 0 {
            return "\(days)天\(hoursAfterDays)小时\(minutes)分"
        }
        if hours > 0 {
            return "\(hours)小时\(minutes)分"
        }
        return "\(minutes)分钟"
    }

    static func longString(until date: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3600
        let minutes = (seconds % 3600) / 60

        if days > 0 {
            return "\(days)天\(hours)小时后"
        }
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟后"
        }
        return "\(minutes)分钟后"
    }
}
