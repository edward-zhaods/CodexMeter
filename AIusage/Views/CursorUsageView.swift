import SwiftUI

struct CursorUsageView: View {
    @ObservedObject var appState: AppState

    @State private var scope: CursorUsageScope = .cycle

    private var snapshot: CursorUsageSnapshot? {
        appState.cursorUsage
    }

    var body: some View {
        if let snapshot {
            hero(snapshot: snapshot)
            quotaSection(snapshot: snapshot)
        } else {
            emptyHero
        }

        modelSection

        if let snapshot {
            TokenActivityView(
                buckets: snapshot.dailyBuckets,
                summary: snapshot.activitySummary
            )
        }

        CursorSettingsCard(appState: appState)
    }

    private func hero(snapshot: CursorUsageSnapshot) -> some View {
        let plan = snapshot.plan
        let cycleTokens = snapshot.totals(in: .cycle)

        return RetroCard(
            fill: MeterTheme.panel,
            cornerRadius: 17,
            shadowOffset: CGSize(width: 6, height: 8)
        ) {
            ZStack(alignment: .topLeading) {
                RetroDotPattern()

                VStack(alignment: .leading, spacing: 11) {
                    Text("INCLUDED USAGE LEFT")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(1.7)
                        .foregroundStyle(MeterTheme.mutedInk)

                    Text(plan.remainingPercentText)
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
                        Text(resetLine(for: plan))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Spacer(minLength: 8)

                        Text("本周期 \(compactTokenText(cycleTokens.total))")
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
                    Text("CURSOR ACCOUNT")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(1.7)
                        .foregroundStyle(MeterTheme.mutedInk)

                    Text(emptyTitle)
                        .font(.system(size: 31, weight: .black, design: .rounded))
                        .foregroundStyle(MeterTheme.ink)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 6)
                        .background(
                            MeterTheme.yellow,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )

                    Text(emptyDetail)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(MeterTheme.mutedInk)
                        .lineLimit(2)
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity, minHeight: 137, alignment: .leading)
        }
    }

    private func quotaSection(snapshot: CursorUsageSnapshot) -> some View {
        let plan = snapshot.plan
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("额度一览")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(MeterTheme.ink)

                Text(plan.planName.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(MeterTheme.mutedInk)
            }

            HStack(alignment: .top, spacing: 9) {
                QuotaCard(window: window(plan: plan, kind: .total), isPrimary: true)
                    .frame(maxWidth: .infinity)
                QuotaCard(window: window(plan: plan, kind: .auto), isPrimary: false)
                    .frame(maxWidth: .infinity)
                if plan.apiUsedPercent > 0 {
                    QuotaCard(window: window(plan: plan, kind: .api), isPrimary: false)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private enum QuotaKind {
        case total
        case auto
        case api
    }

    private func window(plan: CursorPlanSnapshot, kind: QuotaKind) -> QuotaWindowViewModel {
        let used: Double
        let title: String
        let windowKind: QuotaWindowKind
        switch kind {
        case .total:
            used = plan.usedPercent
            title = plan.periodTitle
            windowKind = .fiveHour
        case .auto:
            used = plan.autoUsedPercent
            title = "Auto"
            windowKind = .weekly
        case .api:
            used = plan.apiUsedPercent
            title = "API"
            windowKind = .other
        }
        let clamped = min(max(used, 0), 100)
        return QuotaWindowViewModel(
            id: title,
            kind: windowKind,
            title: title,
            usedPercent: clamped,
            remainingPercent: max(0, 100 - clamped),
            resetDate: plan.cycleEnd,
            windowDurationMins: nil
        )
    }

    private var modelSection: some View {
        RetroCard(
            fill: MeterTheme.panel,
            cornerRadius: 16,
            shadowOffset: CGSize(width: 5, height: 7)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Text("模型用量")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(MeterTheme.ink)

                    Spacer()

                    HStack(spacing: 14) {
                        ForEach(CursorUsageScope.allCases) { item in
                            scopeTab(item)
                        }
                    }
                }

                if let snapshot {
                    let models = snapshot.models(in: scope)
                    if models.isEmpty {
                        placeholder(emptyModelText)
                    } else {
                        let maxTotal = max(1, models.map(\.counters.total).max() ?? 1)
                        VStack(alignment: .leading, spacing: 11) {
                            ForEach(Array(models.enumerated()), id: \.element.id) { index, model in
                                modelRow(
                                    model,
                                    ratio: Double(model.counters.total) / Double(maxTotal),
                                    color: barColor(at: index)
                                )
                            }
                        }
                        let total = snapshot.totals(in: scope)
                        Text("合计 \(compactTokenText(total.total)) · \(total.messages.formatted()) 次 · 输出 \(compactTokenText(total.output))")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(MeterTheme.mutedInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                } else {
                    placeholder("等待 Cursor 用量")
                }
            }
            .padding(15)
        }
    }

    private var emptyModelText: String {
        switch scope {
        case .cycle:
            return "这个计费周期还没有 token 明细"
        case .week:
            return "最近 7 天没有 token 明细"
        case .month:
            return "最近 30 天没有 token 明细"
        case .all:
            return "还没有读到 token 明细"
        }
    }

    private func modelRow(_ model: ClaudeModelUsage, ratio: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(model.displayName)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(MeterTheme.ink)
                    .lineLimit(1)

                Spacer(minLength: 6)

                Text(compactTokenText(model.counters.total))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(MeterTheme.ink)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(MeterTheme.idleBlock.opacity(0.72))

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(MeterTheme.ink, lineWidth: 1)
                        )
                        .frame(width: max(8, proxy.size.width * CGFloat(min(1, max(0, ratio)))))
                }
            }
            .frame(height: 9)

            Text("输出 \(compactTokenText(model.counters.output)) · 输入 \(compactTokenText(model.counters.input)) · 缓存读 \(compactTokenText(model.counters.cacheRead)) · \(model.counters.messages.formatted()) 次")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(MeterTheme.mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func scopeTab(_ item: CursorUsageScope) -> some View {
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

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(MeterTheme.mutedInk)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)
    }

    private func barColor(at index: Int) -> Color {
        let palette = [
            MeterTheme.coral,
            MeterTheme.yellow,
            MeterTheme.pink,
            MeterTheme.blue,
            MeterTheme.success.opacity(0.75),
            MeterTheme.warning.opacity(0.75)
        ]
        return palette[index % palette.count]
    }

    private var emptyTitle: String {
        switch appState.cursorSyncState {
        case .failed:
            return "读取失败"
        case .syncing:
            return "同步中"
        case .idle, .ready:
            return "等待同步"
        }
    }

    private var emptyDetail: String {
        switch appState.cursorSyncState {
        case let .failed(message):
            return message
        case .syncing:
            return "正在读取 Cursor 账号额度和 token 用量"
        case .idle, .ready:
            return "使用本机已登录的 Cursor 账号"
        }
    }

    private func resetLine(for plan: CursorPlanSnapshot) -> String {
        guard let end = plan.cycleEnd else {
            return "\(plan.planName) · 重置时间未知"
        }
        let countdown = CountdownFormatter.shortString(until: end)
        return "\(plan.planName) · \(countdown)后重置"
    }
}

private struct CursorSettingsCard: View {
    @ObservedObject var appState: AppState

    var body: some View {
        RetroCard(
            fill: MeterTheme.panel,
            cornerRadius: 15,
            shadowOffset: CGSize(width: 4, height: 6)
        ) {
            VStack(spacing: 11) {
                HStack(alignment: .center, spacing: 10) {
                    infoBlock(title: "最后同步", value: lastSyncText)

                    Spacer(minLength: 8)

                    infoBlock(title: "用量记录", value: eventText)

                    Button {
                        Task {
                            await appState.refreshCursorUsage(force: true)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(RetroButtonStyle(fill: MeterTheme.yellow, compact: true))
                    .help("重新同步")
                    .disabled(appState.cursorSyncState == .syncing)
                }

                Rectangle()
                    .fill(MeterTheme.ink.opacity(0.16))
                    .frame(height: 1)

                HStack(alignment: .center, spacing: 8) {
                    infoBlock(title: "数据来源", value: "本机 Cursor 登录态")

                    Spacer(minLength: 6)

                    Button("退出") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(RetroButtonStyle(fill: MeterTheme.pink, compact: true))
                }
            }
            .padding(14)
        }
    }

    private func infoBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(MeterTheme.mutedInk)

            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(MeterTheme.ink)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var lastSyncText: String {
        guard let date = appState.cursorUsage?.fetchedAt, date != .distantPast else { return "尚未同步" }
        return date.formatted(date: .omitted, time: .standard)
    }

    private var eventText: String {
        guard let snapshot = appState.cursorUsage else { return "--" }
        let suffix = snapshot.historyComplete ? "" : "+"
        return "\(snapshot.events.count)\(suffix) 条"
    }
}
