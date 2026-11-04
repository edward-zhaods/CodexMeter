import SwiftUI

struct ClaudeUsageView: View {
    @ObservedObject var appState: AppState

    @State private var scope: ClaudeUsageScope = .week

    private var snapshot: ClaudeUsageSnapshot? {
        appState.claudeUsage
    }

    var body: some View {
        if let snapshot {
            hero(snapshot: snapshot)
        } else {
            emptyHero
        }

        StretchHStack(spacing: 10) {
            modelSection

            VStack(alignment: .leading, spacing: 10) {
                TokenActivityView(
                    buckets: snapshot?.dailyBuckets ?? [],
                    summary: snapshot?.activitySummary
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                ClaudeSettingsCard(appState: appState)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .meterColumn(width: MeterPanelMetrics.sideColumnWidth)
        }
    }

    // MARK: - Hero

    private func hero(snapshot: ClaudeUsageSnapshot) -> some View {
        let today = snapshot.totals(in: .today)
        let week = snapshot.totals(in: .week)

        return RetroCard(
            fill: MeterTheme.panel,
            cornerRadius: 17,
            shadowOffset: CGSize(width: 6, height: 8)
        ) {
            ZStack(alignment: .topLeading) {
                RetroDotPattern()

                VStack(alignment: .leading, spacing: 8) {
                    Text("TOKENS TODAY")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(MeterTheme.mutedInk)

                    Text(compactTokens(today.total))
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(MeterTheme.accent(for: .claude))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("输出 \(compactTokens(today.output)) · 缓存读 \(compactTokens(today.cacheRead)) · \(today.messages.formatted()) 轮")
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Spacer(minLength: 8)

                        Text("7 天 \(compactTokens(week.total))")
                            .fontWeight(.bold)
                    }
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(MeterTheme.mutedInk)
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity, minHeight: MeterPanelMetrics.heroMinHeight, alignment: .leading)
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
                    Text("READING LOCAL TRANSCRIPTS")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(MeterTheme.mutedInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(emptyTitle)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(MeterTheme.accent(for: .claude))

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

    private var emptyTitle: String {
        switch appState.claudeScanState {
        case .failed:
            return "读取失败"
        case .scanning:
            return "统计中"
        case .idle, .ready:
            return "等待统计"
        }
    }

    private var emptyDetail: String {
        switch appState.claudeScanState {
        case let .failed(message):
            return message
        case .scanning:
            return "正在读取 ~/.claude/projects 里的会话记录"
        case .idle, .ready:
            return "点击下方刷新按钮开始统计"
        }
    }

    // MARK: - Tokens by model

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
                        ForEach(ClaudeUsageScope.allCases) { item in
                            scopeTab(item)
                        }
                    }
                    .fixedSize()
                }

                if let snapshot {
                    let models = snapshot.models(in: scope)
                    if models.isEmpty {
                        Spacer(minLength: 8)
                        placeholder("这个时间段没有 Claude 记录")
                        Spacer(minLength: 8)
                    } else {
                        let maxTotal = max(1, models.map(\.counters.total).max() ?? 1)
                        modelColumns(models, maxTotal: maxTotal)

                        footer(total: snapshot.totals(in: scope), snapshot: snapshot)
                        Spacer(minLength: 0)
                    }
                } else {
                    Spacer(minLength: 8)
                    placeholder("等待统计结果")
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

    private func modelRow(_ model: ClaudeModelUsage, ratio: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(model.displayName)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(MeterTheme.ink)
                    .lineLimit(1)

                Text(model.modelID)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(MeterTheme.mutedInk.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 6)

                Text(compactTokens(model.counters.total))
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

            Text(breakdownText(model.counters))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(MeterTheme.mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
    }

    private func footer(total: ClaudeTokenCounters, snapshot: ClaudeUsageSnapshot) -> some View {
        HStack(spacing: 5) {
            Text("合计 \(compactTokens(total.total)) · 输出 \(compactTokens(total.output)) · \(total.messages.formatted()) 轮")
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            Text(rangeText(snapshot))
                .lineLimit(1)
        }
        .font(.system(size: 9, weight: .medium, design: .monospaced))
        .foregroundStyle(MeterTheme.mutedInk)
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(MeterTheme.mutedInk)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
    }

    private func scopeTab(_ item: ClaudeUsageScope) -> some View {
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

    private func breakdownText(_ counters: ClaudeTokenCounters) -> String {
        "输出 \(compactTokens(counters.output)) · 输入 \(compactTokens(counters.input)) · 缓存写 \(compactTokens(counters.cacheWrite)) · 缓存读 \(compactTokens(counters.cacheRead)) · \(counters.messages.formatted()) 轮"
    }

    private func rangeText(_ snapshot: ClaudeUsageSnapshot) -> String {
        switch scope {
        case .all:
            if let earliest = snapshot.earliestDayKey {
                return "自 \(earliest) 起"
            }
            return "本机记录"
        case .today, .week, .month:
            return "\(scope.title) · 本机记录"
        }
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
}

private struct ClaudeSettingsCard: View {
    @ObservedObject var appState: AppState

    var body: some View {
        RetroCard(
            fill: MeterTheme.panel,
            cornerRadius: 15,
            shadowOffset: CGSize(width: 4, height: 6)
        ) {
            VStack(spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    infoBlock(title: "最后统计", value: lastScanText)

                    Spacer(minLength: 8)

                    infoBlock(title: "会话文件", value: transcriptText)

                    Button {
                        Task {
                            await appState.refreshClaudeUsage(force: true)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(RetroButtonStyle(fill: MeterTheme.yellow, compact: true, prominent: true))
                    .help("重新统计")
                    .disabled(appState.claudeScanState == .scanning)
                }

                Rectangle()
                    .fill(MeterTheme.ink.opacity(0.16))
                    .frame(height: 1)

                HStack(alignment: .center, spacing: 8) {
                    infoBlock(title: "数据目录", value: appState.claudeProjectsDirectoryPath)

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

    private var lastScanText: String {
        guard let date = appState.claudeUsage?.scannedAt else { return "尚未统计" }
        return date.formatted(date: .omitted, time: .standard)
    }

    private var transcriptText: String {
        guard let snapshot = appState.claudeUsage else { return "--" }
        return "\(snapshot.sessionCount) 会话 · \(snapshot.transcriptCount) 文件"
    }
}

private func compactTokens(_ value: Int64) -> String {
    compactTokenText(value)
}
