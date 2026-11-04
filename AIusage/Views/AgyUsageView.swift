import SwiftUI

struct AgyUsageView: View {
    @ObservedObject var appState: AppState

    private var displayedGroups: [AgyQuotaGroup] {
        appState.agyUsage?.groups ?? []
    }

    var body: some View {
        let groups = displayedGroups
        VStack(alignment: .leading, spacing: 10) {
            if !groups.isEmpty {
                hero(groups)
                groupBoard(groups, headlineID: appState.agyUsage?.tightest(in: groups)?.bucket.id)
            } else {
                emptyHero
            }
        }
    }

    private func groupBoard(_ groups: [AgyQuotaGroup], headlineID: String?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groups) { group in
                groupSection(group, headlineID: headlineID)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hero(_ groups: [AgyQuotaGroup]) -> some View {
        let picked = appState.agyUsage?.tightest(in: groups)
        let bucket = picked?.bucket
        let percent = bucket?.window.remainingPercentText ?? "--"
        let detail = bucket.map { item in
            let date = item.resetDate.map { CountdownFormatter.resetDateText($0) }
            let groupTitle = picked?.groupTitle ?? "Agy"
            if let date {
                return "\(groupTitle) · \(date) · \(item.window.resetLineText)"
            }
            return "\(groupTitle) · \(item.window.resetLineText)"
        } ?? "等待额度数据"

        return RetroCard(
            fill: MeterTheme.panel,
            cornerRadius: 17,
            shadowOffset: CGSize(width: 6, height: 8)
        ) {
            ZStack(alignment: .topLeading) {
                RetroDotPattern()

                VStack(alignment: .leading, spacing: 8) {
                    Text("AGY QUOTA LEFT")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(MeterTheme.mutedInk)

                    Text(percent)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(MeterTheme.accent(for: .agy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text(detail)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(MeterTheme.mutedInk)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity, minHeight: MeterPanelMetrics.heroMinHeight, alignment: .leading)
        }
    }

    private func groupSection(_ group: AgyQuotaGroup, headlineID: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.title)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(MeterTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            bucketBoard(group.buckets, headlineID: headlineID)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bucketBoard(_ buckets: [AgyQuotaBucket], headlineID: String?) -> some View {
        let rowSize = buckets.count > 4 ? 4 : max(buckets.count, 1)
        return VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(stride(from: 0, to: buckets.count, by: rowSize)), id: \.self) { start in
                bucketRow(Array(buckets[start..<min(start + rowSize, buckets.count)]), headlineID: headlineID)
            }
        }
    }

    @ViewBuilder
    private func bucketRow(_ buckets: [AgyQuotaBucket], headlineID: String?) -> some View {
        switch buckets.count {
        case 0:
            EmptyView()
        case 1:
            StretchHStack(spacing: 9) {
                quotaCard(buckets[0], headlineID: headlineID)
            }
        case 2:
            StretchHStack(spacing: 9) {
                quotaCard(buckets[0], headlineID: headlineID)
                quotaCard(buckets[1], headlineID: headlineID)
            }
        case 3:
            StretchHStack(spacing: 9) {
                quotaCard(buckets[0], headlineID: headlineID)
                quotaCard(buckets[1], headlineID: headlineID)
                quotaCard(buckets[2], headlineID: headlineID)
            }
        default:
            StretchHStack(spacing: 9) {
                quotaCard(buckets[0], headlineID: headlineID)
                quotaCard(buckets[1], headlineID: headlineID)
                quotaCard(buckets[2], headlineID: headlineID)
                quotaCard(buckets[3], headlineID: headlineID)
            }
        }
    }

    private func quotaCard(_ bucket: AgyQuotaBucket, headlineID: String?) -> some View {
        QuotaCard(window: bucket.window, isPrimary: bucket.id == headlineID)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                    Text("AGY CLI")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(MeterTheme.mutedInk)

                    Text(emptyTitle)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(MeterTheme.accent(for: .agy))

                    Text(emptyDetail)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(MeterTheme.mutedInk)
                        .lineLimit(3)
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity, minHeight: MeterPanelMetrics.heroMinHeight, alignment: .leading)
        }
    }

    private var emptyTitle: String {
        switch appState.agySyncState {
        case .failed:
            return "读取失败"
        case .ready:
            return "没有额度"
        case .idle, .syncing:
            return "同步中"
        }
    }

    private var emptyDetail: String {
        if case .failed(let message) = appState.agySyncState {
            return message
        }
        return "正在读取本机 Antigravity 额度"
    }
}
