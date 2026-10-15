import SwiftUI

enum MeterTheme {
    static let paper = Color(red: 0.996, green: 0.958, blue: 0.866)
    static let panel = Color(red: 0.998, green: 0.989, blue: 0.958)
    static let ink = Color(red: 0.132, green: 0.112, blue: 0.094)
    static let mutedInk = Color(red: 0.43, green: 0.39, blue: 0.34)
    static let yellow = Color(red: 1.0, green: 0.84, blue: 0.29)
    static let pink = Color(red: 0.96, green: 0.66, blue: 0.76)
    static let blue = Color(red: 0.59, green: 0.81, blue: 0.94)
    static let coral = Color(red: 1.0, green: 0.34, blue: 0.18)
    static let idleBlock = Color(red: 0.93, green: 0.86, blue: 0.70)
    static let success = Color(red: 0.14, green: 0.55, blue: 0.30)
    static let warning = Color(red: 0.82, green: 0.48, blue: 0.05)
    static let danger = Color(red: 0.82, green: 0.16, blue: 0.12)

    static func fill(for kind: QuotaWindowKind) -> Color {
        switch kind {
        case .fiveHour:
            return yellow
        case .weekly:
            return pink
        case .other:
            return blue
        }
    }

    static func healthColor(for level: QuotaHealthLevel) -> Color {
        switch level {
        case .good:
            return success
        case .warning:
            return warning
        case .danger:
            return danger
        }
    }
}

struct RetroCard<Content: View>: View {
    let fill: Color
    let cornerRadius: CGFloat
    let shadowOffset: CGSize
    @ViewBuilder let content: Content

    init(
        fill: Color,
        cornerRadius: CGFloat = 14,
        shadowOffset: CGSize = CGSize(width: 4, height: 6),
        @ViewBuilder content: () -> Content
    ) {
        self.fill = fill
        self.cornerRadius = cornerRadius
        self.shadowOffset = shadowOffset
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            shape
                .fill(MeterTheme.ink)
                .offset(x: shadowOffset.width, y: shadowOffset.height)

            content
                .background(shape.fill(fill))
                .clipShape(shape)
                .overlay(
                    shape
                        .stroke(MeterTheme.ink, lineWidth: 2.4)
                )
        }
        .padding(.trailing, max(0, shadowOffset.width))
        .padding(.bottom, max(0, shadowOffset.height))
    }
}

struct RetroButtonStyle: ButtonStyle {
    var fill: Color = MeterTheme.panel
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 11 : 12, weight: .bold, design: .rounded))
            .foregroundStyle(MeterTheme.ink)
            .padding(.horizontal, compact ? 8 : 11)
            .frame(height: compact ? 26 : 30)
            .background(
                configuration.isPressed ? MeterTheme.yellow : fill,
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(MeterTheme.ink, lineWidth: 1.5)
            )
            .offset(y: configuration.isPressed ? 1 : 0)
    }
}

struct RetroDotPattern: View {
    var body: some View {
        Canvas { context, size in
            for x in stride(from: CGFloat(10), to: size.width, by: 18) {
                for y in stride(from: CGFloat(10), to: size.height, by: 18) {
                    let dot = CGRect(x: x, y: y, width: 3.2, height: 3.2)
                    context.fill(
                        Path(ellipseIn: dot),
                        with: .color(MeterTheme.ink.opacity(0.09))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private enum TokenActivityScope: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case cumulative

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily:
            return "每日"
        case .weekly:
            return "每周"
        case .cumulative:
            return "累计"
        }
    }
}

private struct TokenActivityDay {
    let date: Date
    let tokens: Int64
    let isFuture: Bool
}

private struct TokenMonthMarker: Identifiable {
    let id: String
    let title: String
    let position: Double
}

private enum TokenActivityPalette {
    static let inactive = Color(red: 0.93, green: 0.93, blue: 0.92)

    static func color(for level: Int) -> Color {
        switch level {
        case 1:
            return Color(red: 0.76, green: 0.85, blue: 0.95)
        case 2:
            return Color(red: 0.52, green: 0.70, blue: 0.91)
        case 3:
            return Color(red: 0.25, green: 0.53, blue: 0.85)
        case 4...:
            return Color(red: 0.04, green: 0.38, blue: 0.78)
        default:
            return inactive
        }
    }
}

struct TokenActivityView: View {
    let buckets: [AccountTokenUsageDailyBucket]
    let summary: AccountTokenUsageSummary?

    @State private var scope: TokenActivityScope = .daily

    init(buckets: [AccountTokenUsageDailyBucket], summary: AccountTokenUsageSummary?) {
        self.buckets = buckets
        self.summary = summary
    }

    private var calendar: Calendar {
        Calendar.autoupdatingCurrent
    }

    var body: some View {
        RetroCard(
            fill: MeterTheme.panel,
            cornerRadius: 16,
            shadowOffset: CGSize(width: 5, height: 7)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Token 活动")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(MeterTheme.ink)

                    Spacer()

                    HStack(spacing: 14) {
                        ForEach(TokenActivityScope.allCases) { item in
                            activityTab(item)
                        }
                    }
                }

                Group {
                    switch scope {
                    case .daily:
                        dailyContent
                    case .weekly:
                        weeklyContent
                    case .cumulative:
                        cumulativeContent
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 94, alignment: .top)
            }
            .padding(15)
        }
    }

    private var dailyContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            TokenDailyHeatmap(
                days: dailyDays,
                maxTokens: effectivePeakDailyTokens
            )
            .frame(height: 61)

            TokenMonthAxis(markers: monthMarkers)
                .frame(height: 14)

            HStack(spacing: 5) {
                Text(buckets.isEmpty ? "暂无每日记录" : "过去 12 个月")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(MeterTheme.mutedInk)

                Spacer()

                Text("少")
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(TokenActivityPalette.color(for: level))
                        .frame(width: 9, height: 9)
                }
                Text("多")
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(MeterTheme.mutedInk)
        }
    }

    private var weeklyContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            TokenWeeklyHeatmap(totals: weeklyTotals)
                .frame(height: 61)

            HStack {
                Text("26 周前")
                Spacer()
                Text("本周")
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(MeterTheme.mutedInk)

            Text("每日数据按自然周汇总")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(MeterTheme.mutedInk)
        }
    }

    private var cumulativeContent: some View {
        HStack(spacing: 8) {
            cumulativeMetric(
                title: "累计 TOKEN",
                value: compactTokenCount(summary?.lifetimeTokens)
            )
            cumulativeMetric(
                title: "单日峰值",
                value: compactTokenCount(summary?.peakDailyTokens)
            )
            cumulativeMetric(
                title: "当前连续",
                value: streakText(summary?.currentStreakDays)
            )
            cumulativeMetric(
                title: "最长连续",
                value: streakText(summary?.longestStreakDays)
            )
        }
        .frame(maxHeight: .infinity)
    }

    private func activityTab(_ item: TokenActivityScope) -> some View {
        Button {
            scope = item
        } label: {
            Text(item.title)
                .font(.system(size: 11, weight: scope == item ? .black : .semibold, design: .rounded))
                .foregroundStyle(scope == item ? MeterTheme.ink : MeterTheme.mutedInk.opacity(0.65))
                .padding(.vertical, 4)
                .overlay(alignment: .bottom) {
                    if scope == item {
                        Capsule()
                            .fill(MeterTheme.ink)
                            .frame(height: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func cumulativeMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(MeterTheme.mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(value)
                .font(.system(size: 19, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(MeterTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Spacer(minLength: 0)

            RoundedRectangle(cornerRadius: 3)
                .fill(MeterTheme.coral)
                .frame(height: 7)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(MeterTheme.ink, lineWidth: 1)
                )
        }
        .padding(9)
        .frame(maxWidth: .infinity, minHeight: 83, alignment: .leading)
        .background(
            metricFill(for: title),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(MeterTheme.ink, lineWidth: 1.5)
        )
    }

    private var dailyDays: [TokenActivityDay] {
        let today = calendar.startOfDay(for: Date())
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let startDate = calendar.date(byAdding: .weekOfYear, value: -52, to: thisWeekStart) ?? today
        let tokenLookup = buckets.reduce(into: [String: Int64]()) { result, bucket in
            let key = String(bucket.startDate.prefix(10))
            result[key, default: 0] += max(0, bucket.tokens)
        }

        return (0..<(53 * 7)).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else {
                return nil
            }
            return TokenActivityDay(
                date: date,
                tokens: tokenLookup[dateKey(date), default: 0],
                isFuture: date > today
            )
        }
    }

    private var monthMarkers: [TokenMonthMarker] {
        guard
            let startDate = dailyDays.first?.date,
            let endDate = dailyDays.last?.date
        else {
            return []
        }

        let startComponents = calendar.dateComponents([.year, .month], from: startDate)
        guard var monthDate = calendar.date(from: startComponents) else { return [] }
        let totalDays = max(1, calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
        var markers: [TokenMonthMarker] = []

        while monthDate <= endDate {
            if monthDate >= startDate {
                let components = calendar.dateComponents([.year, .month], from: monthDate)
                let elapsedDays = calendar.dateComponents([.day], from: startDate, to: monthDate).day ?? 0
                let month = components.month ?? 0
                markers.append(
                    TokenMonthMarker(
                        id: "\(components.year ?? 0)-\(month)",
                        title: "\(month)月",
                        position: min(1, max(0, Double(elapsedDays) / Double(totalDays)))
                    )
                )
            }

            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthDate) else {
                break
            }
            monthDate = nextMonth
        }

        return markers
    }

    private var weeklyTotals: [Int64] {
        let totals = stride(from: 0, to: dailyDays.count, by: 7).map { start in
            dailyDays[start..<min(start + 7, dailyDays.count)]
                .reduce(Int64(0)) { $0 + $1.tokens }
        }
        return Array(totals.suffix(26))
    }

    private var effectivePeakDailyTokens: Int64 {
        max(
            1,
            summary?.peakDailyTokens ?? buckets.map(\.tokens).max() ?? 1
        )
    }

    private func dateKey(_ date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private func compactTokenCount(_ count: Int64?) -> String {
        guard let count else { return "--" }
        return max(0, count).formatted(
            .number
                .notation(.compactName)
                .precision(.fractionLength(0...1))
        )
    }

    private func streakText(_ days: Int64?) -> String {
        guard let days else { return "--" }
        return "\(max(0, days))天"
    }

    private func metricFill(for title: String) -> Color {
        switch title {
        case "累计 TOKEN":
            return MeterTheme.yellow.opacity(0.86)
        case "单日峰值":
            return MeterTheme.pink.opacity(0.84)
        case "当前连续":
            return MeterTheme.blue.opacity(0.86)
        default:
            return MeterTheme.paper
        }
    }
}

private struct TokenDailyHeatmap: View {
    let days: [TokenActivityDay]
    let maxTokens: Int64

    var body: some View {
        Canvas { context, size in
            let columns = 53
            let rows = 7
            let gap: CGFloat = 2
            let cellWidth = (size.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
            let cellHeight = (size.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
            let cellSize = max(2, min(cellWidth, cellHeight))

            for (index, day) in days.enumerated() {
                let column = index / rows
                let row = index % rows
                let rect = CGRect(
                    x: CGFloat(column) * (cellWidth + gap),
                    y: CGFloat(row) * (cellHeight + gap),
                    width: cellSize,
                    height: cellSize
                )
                let level = day.isFuture ? 0 : activityLevel(tokens: day.tokens, maximum: maxTokens)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: min(2, cellSize / 3)),
                    with: .color(TokenActivityPalette.color(for: level).opacity(day.isFuture ? 0.42 : 1))
                )
            }
        }
        .accessibilityLabel("每日 Token 活动热力图")
    }
}

private struct TokenWeeklyHeatmap: View {
    let totals: [Int64]

    var body: some View {
        Canvas { context, size in
            let columns = max(1, totals.count)
            let rows = 4
            let gap: CGFloat = 3
            let cellWidth = (size.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
            let cellHeight = (size.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
            let maximum = max(1, totals.max() ?? 1)

            for (column, total) in totals.enumerated() {
                let level = activityLevel(tokens: total, maximum: maximum)
                for row in 0..<rows {
                    let isFilled = row >= rows - level
                    let rect = CGRect(
                        x: CGFloat(column) * (cellWidth + gap),
                        y: CGFloat(row) * (cellHeight + gap),
                        width: cellWidth,
                        height: cellHeight
                    )
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: min(3, cellWidth / 3)),
                        with: .color(
                            isFilled
                                ? TokenActivityPalette.color(for: level)
                                : TokenActivityPalette.inactive
                        )
                    )
                }
            }
        }
        .accessibilityLabel("每周 Token 活动热力图")
    }
}

private struct TokenMonthAxis: View {
    let markers: [TokenMonthMarker]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(markers) { marker in
                    Text(marker.title)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(MeterTheme.mutedInk.opacity(0.78))
                        .position(
                            x: max(10, min(proxy.size.width - 10, proxy.size.width * marker.position)),
                            y: 7
                        )
                }
            }
        }
    }
}

private func activityLevel(tokens: Int64, maximum: Int64) -> Int {
    guard tokens > 0, maximum > 0 else { return 0 }
    let ratio = log1p(Double(tokens)) / log1p(Double(maximum))
    switch ratio {
    case ..<0.35:
        return 1
    case ..<0.58:
        return 2
    case ..<0.8:
        return 3
    default:
        return 4
    }
}

struct MeterPopoverView: View {
    @ObservedObject var appState: AppState

    private var heroWindow: QuotaWindowViewModel? {
        appState.fiveHourWindow ?? appState.weeklyWindow
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                header
                providerSwitch

                switch appState.selectedProvider {
                case .codex:
                    codexContent
                case .claude:
                    ClaudeUsageView(appState: appState)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 17)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .frame(width: 460, height: 620)
        .background(MeterTheme.paper)
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder
    private var codexContent: some View {
        if let heroWindow {
            hero(window: heroWindow)
        } else {
            emptyHero
        }

        quotaSection

        TokenActivityView(
            buckets: appState.tokenUsageDailyBuckets,
            summary: appState.tokenUsageSummary
        )

        SettingsView(appState: appState)
    }

    private var providerSwitch: some View {
        HStack(spacing: 8) {
            ForEach(MeterProvider.allCases) { provider in
                Button {
                    appState.selectedProvider = provider
                    if provider == .claude {
                        Task {
                            await appState.refreshClaudeUsage()
                        }
                    }
                } label: {
                    Text(provider.title)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    RetroButtonStyle(
                        fill: appState.selectedProvider == provider ? MeterTheme.pink : MeterTheme.panel
                    )
                )
            }
        }
    }

    private var headerLabel: String {
        switch appState.selectedProvider {
        case .codex:
            return "CODEX METER"
        case .claude:
            return "CLAUDE CODE"
        }
    }

    private var headerTitle: String {
        switch appState.selectedProvider {
        case .codex:
            return "额度面板"
        case .claude:
            return "用量面板"
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(headerLabel)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(MeterTheme.mutedInk)

                Text(headerTitle)
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .foregroundStyle(MeterTheme.ink)
            }

            Spacer()
            statusBadge
        }
    }

    private func hero(window: QuotaWindowViewModel) -> some View {
        RetroCard(
            fill: MeterTheme.panel,
            cornerRadius: 17,
            shadowOffset: CGSize(width: 6, height: 8)
        ) {
            ZStack(alignment: .topLeading) {
                RetroDotPattern()

                VStack(alignment: .leading, spacing: 11) {
                    Text("TIME UNTIL NEXT RESET")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(1.7)
                        .foregroundStyle(MeterTheme.mutedInk)

                    Text(heroCountdownText(for: window))
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(MeterTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 6)
                        .background(
                            MeterTheme.yellow,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                        .rotationEffect(.degrees(-0.7), anchor: .leading)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(heroResetDateText(for: window))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Spacer(minLength: 8)

                        Text("\(window.remainingPercentText) 剩余")
                            .fontWeight(.bold)
                    }
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(MeterTheme.mutedInk)
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity, minHeight: 137, alignment: .leading)
        }
    }

    private var emptyHero: some View {
        RetroCard(
            fill: MeterTheme.panel,
            cornerRadius: 17,
            shadowOffset: CGSize(width: 6, height: 8)
        ) {
            ZStack(alignment: .topLeading) {
                RetroDotPattern()

                VStack(alignment: .leading, spacing: 12) {
                    Text("CONNECTING TO CODEX")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(1.7)
                        .foregroundStyle(MeterTheme.mutedInk)

                    Text("额度同步中")
                        .font(.system(size: 31, weight: .black, design: .rounded))
                        .foregroundStyle(MeterTheme.ink)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 6)
                        .background(
                            MeterTheme.yellow,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )

                    Text("正在读取 Codex app-server 数据")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(MeterTheme.mutedInk)
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity, minHeight: 137, alignment: .leading)
        }
    }

    private var quotaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("额度一览")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(MeterTheme.ink)

                Text("RATE LIMIT WINDOWS")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(MeterTheme.mutedInk)
            }

            HStack(alignment: .top, spacing: 9) {
                if let fiveHourWindow = appState.fiveHourWindow {
                    QuotaCard(
                        window: fiveHourWindow,
                        isPrimary: fiveHourWindow.id == heroWindow?.id
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    missingQuotaCard(title: "5 小时额度", fill: MeterTheme.yellow)
                        .frame(maxWidth: .infinity)
                }

                if let weeklyWindow = appState.weeklyWindow {
                    QuotaCard(
                        window: weeklyWindow,
                        isPrimary: weeklyWindow.id == heroWindow?.id
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    missingQuotaCard(title: "周额度", fill: MeterTheme.pink)
                        .frame(maxWidth: .infinity)
                }

                lifetimeTokenCard
                    .frame(maxWidth: .infinity)
            }

            ForEach(appState.otherWindows) { window in
                QuotaCard(window: window, isPrimary: false)
            }
        }
    }

    private var lifetimeTokenCard: some View {
        RetroCard(fill: MeterTheme.blue) {
            VStack(alignment: .leading, spacing: 7) {
                Text("累计 TOKENS")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(MeterTheme.mutedInk)
                    .lineLimit(1)

                Text(lifetimeTokenText)
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(MeterTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Spacer(minLength: 0)

                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(MeterTheme.coral)
                        .frame(width: 12, height: 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(MeterTheme.ink, lineWidth: 1.2)
                        )
                    Text("APP-SERVER")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(MeterTheme.mutedInk)
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
        }
    }

    private func missingQuotaCard(title: String, fill: Color) -> some View {
        RetroCard(fill: fill) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(MeterTheme.mutedInk)
                    .lineLimit(1)

                Text("--")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(MeterTheme.ink)

                Spacer(minLength: 0)

                Text("等待数据")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(MeterTheme.mutedInk)
            }
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(MeterTheme.ink, lineWidth: 1))

            Text(statusBadgeText)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(MeterTheme.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            MeterTheme.panel,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(MeterTheme.ink, lineWidth: 1.6)
        )
    }

    private func heroCountdownText(for window: QuotaWindowViewModel) -> String {
        window.resetCountdownShort.map { "\($0)后" } ?? "等待重置时间"
    }

    private func heroResetDateText(for window: QuotaWindowViewModel) -> String {
        guard let resetDate = window.resetDate else {
            return "\(window.title) · 重置时间未知"
        }
        return "\(window.title) · \(resetDate.formatted(date: .abbreviated, time: .shortened))"
    }

    private var lifetimeTokenText: String {
        guard let lifetimeTokenCount = appState.lifetimeTokenCount else { return "--" }
        return max(0, lifetimeTokenCount).formatted(
            .number
                .notation(.compactName)
                .precision(.fractionLength(0...1))
        )
    }

    private var statusBadgeText: String {
        switch appState.selectedProvider {
        case .codex:
            return appState.isCachedDataStale ? "缓存" : appState.statusText
        case .claude:
            return appState.claudeStatusText
        }
    }

    private var statusColorName: String {
        switch appState.selectedProvider {
        case .codex:
            return appState.statusColorName
        case .claude:
            return appState.claudeStatusColorName
        }
    }

    private var statusColor: Color {
        switch statusColorName {
        case "green":
            return MeterTheme.success
        case "orange":
            return MeterTheme.warning
        default:
            return MeterTheme.danger
        }
    }
}
