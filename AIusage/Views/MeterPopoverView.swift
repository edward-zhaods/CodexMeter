import SwiftUI

enum MeterTheme {
    static let paper = Color(red: 0.07, green: 0.06, blue: 0.12)
    static let panel = Color(red: 0.11, green: 0.10, blue: 0.18)
    static let ink = Color(red: 0.95, green: 0.96, blue: 0.99)
    static let mutedInk = Color(red: 0.62, green: 0.67, blue: 0.78)
    static let onAccent = Color(red: 0.07, green: 0.06, blue: 0.12)
    static let yellow = Color(red: 1.0, green: 0.84, blue: 0.29)
    static let pink = Color(red: 0.98, green: 0.55, blue: 0.74)
    static let blue = Color(red: 0.45, green: 0.78, blue: 1.0)
    static let coral = Color(red: 1.0, green: 0.45, blue: 0.32)
    static let idleBlock = Color(red: 0.20, green: 0.22, blue: 0.32)
    static let success = Color(red: 0.30, green: 0.86, blue: 0.52)
    static let warning = Color(red: 1.0, green: 0.72, blue: 0.28)
    static let danger = Color(red: 1.0, green: 0.40, blue: 0.36)

    static func accent(for provider: MeterProvider) -> Color {
        switch provider {
        case .codex:
            return Color(red: 0.22, green: 0.86, blue: 0.49)
        case .cursor:
            return Color(red: 0.67, green: 0.48, blue: 0.98)
        case .agy:
            return Color(red: 0.31, green: 0.72, blue: 1)
        case .claude:
            return Color(red: 1, green: 0.62, blue: 0.32)
        }
    }

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

enum MeterPanelMetrics {
    static let width: CGFloat = 880
    static let heroWidth: CGFloat = 340
    static let sideColumnWidth: CGFloat = 360
    static let heroMinHeight: CGFloat = 120
    static let cardMinHeight: CGFloat = 120
}

@MainActor
final class MeterPanelSizer: ObservableObject {
    @Published var maxContentHeight: CGFloat = 860
    var onContentHeight: ((CGFloat) -> Void)?
}

private struct PanelContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MeterColumnWidth: LayoutValueKey {
    static let defaultValue: CGFloat? = nil
}

extension View {
    func meterColumn(width: CGFloat) -> some View {
        layoutValue(key: MeterColumnWidth.self, value: width)
    }
}

struct StretchHStack: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let widths = columnWidths(proposal: proposal, subviews: subviews)
        let height = rowHeight(widths: widths, subviews: subviews)
        let used = usedWidth(widths)
        return CGSize(width: max(proposal.width ?? used, used), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = columnWidths(
            proposal: ProposedViewSize(width: bounds.width, height: proposal.height),
            subviews: subviews
        )
        var x = bounds.minX
        for index in subviews.indices {
            let width = widths[index]
            subviews[index].place(
                at: CGPoint(x: x, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            x += width + spacing
        }
    }

    private func rowHeight(widths: [CGFloat], subviews: Subviews) -> CGFloat {
        var height: CGFloat = 0
        for index in subviews.indices {
            let measured = subviews[index]
                .sizeThatFits(ProposedViewSize(width: widths[index], height: nil))
                .height
            height = max(height, measured)
        }
        return height
    }

    private func usedWidth(_ widths: [CGFloat]) -> CGFloat {
        guard !widths.isEmpty else { return 0 }
        return widths.reduce(0, +) + spacing * CGFloat(widths.count - 1)
    }

    private func columnWidths(proposal: ProposedViewSize, subviews: Subviews) -> [CGFloat] {
        let count = subviews.count
        guard count > 0 else { return [] }

        let gaps = spacing * CGFloat(count - 1)
        let available = max(0, (proposal.width ?? 0) - gaps)
        var widths = Array(repeating: CGFloat(0), count: count)
        var flexible: [Int] = []
        var fixedSum: CGFloat = 0

        for index in subviews.indices {
            if let fixed = subviews[index][MeterColumnWidth.self] {
                widths[index] = fixed
                fixedSum += fixed
            } else {
                flexible.append(index)
            }
        }

        if proposal.width == nil {
            for index in flexible {
                widths[index] = subviews[index]
                    .sizeThatFits(ProposedViewSize(width: nil, height: nil))
                    .width
            }
            return widths
        }

        let share = flexible.isEmpty
            ? CGFloat(0)
            : max(0, available - fixedSum) / CGFloat(flexible.count)
        for index in flexible {
            widths[index] = share
        }
        return widths
    }
}

func meterSectionHeading(_ title: String, caption: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(title)
            .font(.system(size: 17, weight: .black, design: .rounded))
            .foregroundStyle(MeterTheme.ink)
            .lineLimit(1)

        Text(caption)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(1.1)
            .foregroundStyle(MeterTheme.mutedInk)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private struct MeterAccentKey: EnvironmentKey {
    static let defaultValue = Color(red: 0.22, green: 0.86, blue: 0.49)
}

extension EnvironmentValues {
    var meterAccent: Color {
        get { self[MeterAccentKey.self] }
        set { self[MeterAccentKey.self] = newValue }
    }
}

struct RetroCard<Content: View>: View {
    @Environment(\.meterAccent) private var meterAccent
    let cornerRadius: CGFloat
    let content: Content

    init(
        fill: Color = MeterTheme.panel,
        cornerRadius: CGFloat = 14,
        shadowOffset: CGSize = CGSize(width: 4, height: 6),
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
        _ = fill
        _ = shadowOffset
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                ZStack {
                    shape.fill(MeterTheme.panel)
                    shape.fill(meterAccent.opacity(0.10))
                }
            }
            .clipShape(shape)
            .overlay(shape.stroke(meterAccent, lineWidth: 1.5))
            .shadow(color: meterAccent.opacity(0.28), radius: 8, y: 0)
    }
}

struct RetroButtonStyle: ButtonStyle {
    var fill: Color = MeterTheme.panel
    var compact = false
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(size: compact ? 11 : 12, weight: .bold, design: .rounded))
            .foregroundStyle((prominent || pressed) ? MeterTheme.onAccent : MeterTheme.ink)
            .padding(.horizontal, compact ? 8 : 11)
            .frame(height: compact ? 26 : 30)
            .background(
                pressed ? MeterTheme.yellow : fill,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        prominent ? Color.black.opacity(0.28) : Color.white.opacity(0.16),
                        lineWidth: 1
                    )
            )
            .offset(y: pressed ? 1 : 0)
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
                        with: .color(MeterTheme.ink.opacity(0.16))
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
    static let inactive = Color(red: 0.18, green: 0.20, blue: 0.28)

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
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Token 活动")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(MeterTheme.ink)

                    Spacer()

                    HStack(spacing: 12) {
                        ForEach(TokenActivityScope.allCases) { item in
                            activityTab(item)
                        }
                    }
                    .fixedSize()
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
                .frame(maxWidth: .infinity, minHeight: 88, alignment: .top)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                .fill(metricFill(for: title))
                .frame(height: 7)
        }
        .padding(9)
        .frame(maxWidth: .infinity, minHeight: 83, alignment: .leading)
        .background(
            MeterTheme.panel,
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
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
            return MeterTheme.yellow
        case "单日峰值":
            return MeterTheme.pink
        case "当前连续":
            return MeterTheme.blue
        default:
            return MeterTheme.coral
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
    @ObservedObject var sizer: MeterPanelSizer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentHeight: CGFloat = 0

    private var heroWindow: QuotaWindowViewModel? {
        appState.fiveHourWindow ?? appState.weeklyWindow
    }

    private var needsScroll: Bool {
        contentHeight > sizer.maxContentHeight + 1
    }

    var body: some View {
        Group {
            if needsScroll {
                ScrollView(.vertical) {
                    panelStack
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(width: MeterPanelMetrics.width, height: sizer.maxContentHeight, alignment: .top)
            } else {
                panelStack
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .background(MeterTheme.paper)
        .environment(\.colorScheme, .dark)
        .environment(\.meterAccent, MeterTheme.accent(for: appState.selectedProvider))
        .onPreferenceChange(PanelContentHeightKey.self) { height in
            guard height > 80, abs(height - contentHeight) > 0.5 else { return }
            contentHeight = height
            sizer.onContentHeight?(height)
        }
    }

    private var panelStack: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            providerSwitch
            providerPage
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .frame(width: MeterPanelMetrics.width, alignment: .topLeading)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: PanelContentHeightKey.self,
                    value: proxy.size.width >= MeterPanelMetrics.width - 1 ? proxy.size.height : 0
                )
            }
        }
    }

    @ViewBuilder
    private var providerPage: some View {
        switch appState.selectedProvider {
        case .codex:
            codexContent
        case .claude:
            ClaudeUsageView(appState: appState)
        case .cursor:
            CursorUsageView(appState: appState)
        case .agy:
            AgyUsageView(appState: appState)
        }
    }

    @ViewBuilder
    private var codexContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            meterSectionHeading("额度一览", caption: "RATE LIMIT WINDOWS")

            StretchHStack(spacing: 10) {
                codexHero
                    .meterColumn(width: MeterPanelMetrics.heroWidth)
                fiveHourCard
                weeklyCard
                lifetimeTokenCard
            }

            ForEach(appState.otherWindows) { window in
                QuotaCard(window: window, isPrimary: false)
            }
        }

        StretchHStack(spacing: 10) {
            TokenActivityView(
                buckets: appState.tokenUsageDailyBuckets,
                summary: appState.tokenUsageSummary
            )
            SettingsView(appState: appState)
                .meterColumn(width: MeterPanelMetrics.sideColumnWidth)
        }
    }

    @ViewBuilder
    private var codexHero: some View {
        if let heroWindow {
            hero(window: heroWindow)
        } else {
            emptyHero
        }
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
                    if provider == .cursor {
                        Task {
                            await appState.refreshCursorUsage()
                        }
                    }
                    if provider == .agy {
                        Task {
                            await appState.refreshAgyUsage()
                        }
                    }
                } label: {
                    Text(provider.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    RetroButtonStyle(
                        fill: appState.selectedProvider == provider
                            ? MeterTheme.accent(for: provider)
                            : MeterTheme.panel,
                        prominent: appState.selectedProvider == provider
                    )
                )
            }
        }
    }

    private var selectedPet: PetKind {
        switch appState.selectedProvider {
        case .codex:
            return .codex
        case .cursor:
            return .cursor
        case .agy:
            return .gemini
        case .claude:
            return .claude
        }
    }

    private var header: some View {
        let pet = selectedPet
        let mood = appState.petMoods[pet] ?? .idle
        return HStack(alignment: .center, spacing: 12) {
            headerSprite(pet: pet, mood: mood)

            VStack(alignment: .leading, spacing: 2) {
                Text(pet.menuTitle(vacation: false))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(MeterTheme.ink)
                    .lineLimit(1)

                Text(pet.subtitle(vacation: false))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(MeterTheme.accent(for: appState.selectedProvider))
                    .lineLimit(1)
            }

            Spacer()
            statusBadge
        }
    }

    private func headerSprite(pet: PetKind, mood: PetMood) -> some View {
        TimelineView(.animation(minimumInterval: 0.35, paused: reduceMotion || mood != .working)) { timeline in
            let tick = Int(timeline.date.timeIntervalSinceReferenceDate / 0.35)
            let frame = mood == .working && !reduceMotion
                ? PetPixels.frameIndex(for: pet, frame: tick)
                : 0
            let sprite = PetPixels.image(
                for: pet,
                pose: mood == .working ? .working : .idle,
                frame: frame
            )
            Image(nsImage: sprite)
                .resizable()
                .interpolation(.none)
                .frame(width: sprite.size.width * 3, height: sprite.size.height * 3)
                .opacity(mood == .offline ? 0.4 : 1)
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("TIME UNTIL NEXT RESET")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(MeterTheme.mutedInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(heroCountdownText(for: window))
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(MeterTheme.accent(for: .codex))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Spacer(minLength: 0)

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
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: MeterPanelMetrics.heroMinHeight,
                maxHeight: .infinity,
                alignment: .topLeading
            )
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("CONNECTING TO CODEX")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(MeterTheme.mutedInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("额度同步中")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(MeterTheme.accent(for: .codex))

                    Text("正在读取 Codex app-server 数据")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(MeterTheme.mutedInk)
                }
                .padding(14)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: MeterPanelMetrics.heroMinHeight,
                maxHeight: .infinity,
                alignment: .topLeading
            )
        }
    }

    @ViewBuilder
    private var fiveHourCard: some View {
        if let fiveHourWindow = appState.fiveHourWindow {
            QuotaCard(
                window: fiveHourWindow,
                isPrimary: fiveHourWindow.id == heroWindow?.id
            )
        } else {
            missingQuotaCard(title: "5 小时额度", fill: MeterTheme.yellow)
        }
    }

    @ViewBuilder
    private var weeklyCard: some View {
        if let weeklyWindow = appState.weeklyWindow {
            QuotaCard(
                window: weeklyWindow,
                isPrimary: weeklyWindow.id == heroWindow?.id
            )
        } else {
            missingQuotaCard(title: "周额度", fill: MeterTheme.pink)
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
                    .font(.system(size: 24, weight: .black, design: .rounded))
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
                                .stroke(Color.black.opacity(0.28), lineWidth: 1.2)
                        )
                    Text("APP-SERVER")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(MeterTheme.mutedInk)
                }
            }
            .padding(11)
            .frame(
                maxWidth: .infinity,
                minHeight: MeterPanelMetrics.cardMinHeight,
                maxHeight: .infinity,
                alignment: .topLeading
            )
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
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(MeterTheme.ink)

                Spacer(minLength: 0)

                Text("等待数据")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(MeterTheme.mutedInk)
            }
            .padding(11)
            .frame(
                maxWidth: .infinity,
                minHeight: MeterPanelMetrics.cardMinHeight,
                maxHeight: .infinity,
                alignment: .topLeading
            )
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))

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
                .stroke(MeterTheme.accent(for: appState.selectedProvider), lineWidth: 1.2)
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
        case .cursor:
            return appState.cursorStatusText
        case .agy:
            return appState.agyStatusText
        }
    }

    private var statusColorName: String {
        switch appState.selectedProvider {
        case .codex:
            return appState.statusColorName
        case .claude:
            return appState.claudeStatusColorName
        case .cursor:
            return appState.cursorStatusColorName
        case .agy:
            return appState.agyStatusColorName
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
