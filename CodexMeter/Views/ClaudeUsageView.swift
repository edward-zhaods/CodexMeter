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

        modelSection

        TokenActivityView(
            buckets: snapshot?.dailyBuckets ?? [],
            summary: snapshot?.activitySummary
        )

        ClaudeSettingsCard(appState: appState)
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

                VStack(alignment: .leading, spacing: 11) {
                    Text("TOKENS TODAY")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(1.7)
                        .foregroundStyle(MeterTheme.mutedInk)

                    Text(compactTokens(today.total))
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
                    Text("READING LOCAL TRANSCRIPTS")
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
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Text("模型用量")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(MeterTheme.ink)

                    Spacer()

                    HStack(spacing: 14) {
                        ForEach(ClaudeUsageScope.allCases) { item in
                            scopeTab(item)
                        }
                    }
                }

                if let snapshot {
                    let models = snapshot.models(in: scope)
                    if models.isEmpty {
                        placeholder("这个时间段没有 Claude 记录")
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

                        footer(total: snapshot.totals(in: scope), snapshot: snapshot)
                    }
                } else {
                    placeholder("等待统计结果")
                }
            }
            .padding(15)
        }
    }

    private func modelRow(_ model: ClaudeModelUsage, ratio: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
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
                                .stroke(MeterTheme.ink, lineWidth: 1)
                        )
                        .frame(width: max(8, proxy.size.width * CGFloat(min(1, max(0, ratio)))))
                }
            }
            .frame(height: 9)

            Text(breakdownText(model.counters))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(MeterTheme.mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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
            VStack(spacing: 11) {
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
                    .buttonStyle(RetroButtonStyle(fill: MeterTheme.yellow, compact: true))
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
    max(0, value).formatted(
        .number
            .notation(.compactName)
            .precision(.fractionLength(0...1))
    )
}
