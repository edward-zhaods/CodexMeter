import SwiftUI

struct CursorUsageView: View {
    @ObservedObject var appState: AppState

    @State private var scope: CursorUsageScope = .cycle

    private var snapshot: CursorUsageSnapshot? {
        appState.cursorUsage
    }

    var body: some View {
        if let snapshot {
            VStack(alignment: .leading, spacing: 8) {
                meterSectionHeading("额度一览", caption: snapshot.plan.planName.uppercased())
                cursorQuotaRow(snapshot: snapshot)
            }

            detailBand(
                buckets: snapshot.dailyBuckets,
                summary: snapshot.activitySummary
            )
        } else {
            emptyHero
            detailBand(buckets: [], summary: nil)
        }
    }

    @ViewBuilder
    private func cursorQuotaRow(snapshot: CursorUsageSnapshot) -> some View {
        let plan = snapshot.plan
        if plan.apiUsedPercent > 0 {
            StretchHStack(spacing: 10) {
                hero(snapshot: snapshot)
                    .meterColumn(width: MeterPanelMetrics.heroWidth)
                QuotaCard(window: window(plan: plan, kind: .total), isPrimary: true)
                QuotaCard(window: window(plan: plan, kind: .auto), isPrimary: false)
                QuotaCard(window: window(plan: plan, kind: .api), isPrimary: false)
            }
        } else {
            StretchHStack(spacing: 10) {
                hero(snapshot: snapshot)
                    .meterColumn(width: MeterPanelMetrics.heroWidth)
                QuotaCard(window: window(plan: plan, kind: .total), isPrimary: true)
                QuotaCard(window: window(plan: plan, kind: .auto), isPrimary: false)
            }
        }
    }

    private func detailBand(
        buckets: [AccountTokenUsageDailyBucket],
        summary: AccountTokenUsageSummary?
    ) -> some View {
        StretchHStack(spacing: 10) {
            modelSection

            VStack(alignment: .leading, spacing: 10) {
                if summary != nil || !buckets.isEmpty {
                    TokenActivityView(buckets: buckets, summary: summary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    Spacer(minLength: 0)
                }
                CursorSettingsCard(appState: appState)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .meterColumn(width: MeterPanelMetrics.sideColumnWidth)
        }
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("INCLUDED USAGE LEFT")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(MeterTheme.mutedInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(plan.remainingPercentText)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(MeterTheme.accent(for: .cursor))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Spacer(minLength: 0)

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
                    Text("CURSOR ACCOUNT")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(MeterTheme.mutedInk)

                    Text(emptyTitle)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(MeterTheme.accent(for: .cursor))

                    Text(emptyDetail)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(MeterTheme.mutedInk)
                        .lineLimit(2)
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity, minHeight: MeterPanelMetrics.heroMinHeight, alignment: .leading)
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
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 12) {
                    Text("模型用量")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(MeterTheme.ink)

                    Spacer()

                    HStack(spacing: 10) {
                        ForEach(CursorUsageScope.allCases) { item in
                            scopeTab(item)
                        }
                    }
                    .fixedSize()
                }

                if let snapshot {
                    let models = snapshot.models(in: scope)
                    if models.isEmpty {
                        Spacer(minLength: 8)
                        placeholder(emptyModelText)
                        Spacer(minLength: 8)
                    } else {
                        let maxTotal = max(1, models.map(\.counters.total).max() ?? 1)
                        modelColumns(models, maxTotal: maxTotal)
                        let total = snapshot.totals(in: scope)
                        Text("合计 \(compactTokenText(total.total)) · \(total.messages.formatted()) 次 · 输出 \(compactTokenText(total.output))")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(MeterTheme.mutedInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                    }
                } else {
                    Spacer(minLength: 8)
                    placeholder("等待 Cursor 用量")
                    Spacer(minLength: 8)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func modelColumns(_ models: [ClaudeModelUsage], maxTotal: Int64) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(stride(from: 0, to: models.count, by: 2)), id: \.self) { start in
                HStack(alignment: .top, spacing: 12) {
                    modelCell(models[start], maxTotal: maxTotal, index: start)
                    if start + 1 < models.count {
                        modelCell(models[start + 1], maxTotal: maxTotal, index: start + 1)
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func modelCell(_ model: ClaudeModelUsage, maxTotal: Int64, index: Int) -> some View {
        modelRow(
            model,
            ratio: Double(model.counters.total) / Double(max(1, maxTotal)),
            color: barColor(at: index)
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
        VStack(alignment: .leading, spacing: 4) {
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
                                .stroke(Color.black.opacity(0.28), lineWidth: 1)
                        )
                        .frame(width: max(8, proxy.size.width * CGFloat(min(1, max(0, ratio)))))
                }
            }
            .frame(height: 8)

            Text("输出 \(compactTokenText(model.counters.output)) · 输入 \(compactTokenText(model.counters.input)) · 缓存读 \(compactTokenText(model.counters.cacheRead)) · \(model.counters.messages.formatted()) 次")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(MeterTheme.mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
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
            VStack(spacing: 8) {
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
                    .buttonStyle(RetroButtonStyle(fill: MeterTheme.yellow, compact: true, prominent: true))
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
                    .buttonStyle(RetroButtonStyle(fill: MeterTheme.pink, compact: true, prominent: true))
                }
            }
            .padding(12)
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
