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

    /// Calendar reset date, for example `11月11日`. Adds the year when it is not this year.
    static func resetDateText(_ date: Date, now: Date = Date()) -> String {
        formatted(date, template: sameYear(date, now) ? "MMMd" : "yMMMd")
    }

    /// Short calendar reset date, for example `11/11`.
    static func resetDateShort(_ date: Date, now: Date = Date()) -> String {
        formatted(date, template: sameYear(date, now) ? "Md" : "yMd")
    }

    private static func sameYear(_ date: Date, _ now: Date) -> Bool {
        Calendar.current.component(.year, from: date) == Calendar.current.component(.year, from: now)
    }

    private static func formatted(_ date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}
