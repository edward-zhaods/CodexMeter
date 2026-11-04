import SwiftUI

struct AgyUsageView: View {
    @ObservedObject var appState: AppState

    private var displayedGroups: [AgyQuotaGroup] {
        appState.agyUsage?.groups ?? []
    }

    var body: some View {
        let groups = displayedGroups
        if !groups.isEmpty {
            hero(groups)
            ForEach(groups) { group in
                groupSection(group, headlineID: appState.agyUsage?.tightest(in: groups)?.bucket.id)
            }
        } else {
            emptyHero
        }
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

                VStack(alignment: .leading, spacing: 11) {
                    Text("AGY QUOTA LEFT")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(1.7)
                        .foregroundStyle(MeterTheme.mutedInk)

                    Text(percent)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(MeterTheme.accent(for: .agy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(detail)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(MeterTheme.mutedInk)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity, minHeight: 137, alignment: .leading)
        }
    }

    private func groupSection(_ group: AgyQuotaGroup, headlineID: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(group.title)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(MeterTheme.ink)

            HStack(alignment: .top, spacing: 9) {
                ForEach(group.buckets) { bucket in
                    QuotaCard(window: bucket.window, isPrimary: bucket.id == headlineID)
                        .frame(maxWidth: .infinity)
                }
            }
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
                    Text("AGY CLI")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(1.7)
                        .foregroundStyle(MeterTheme.mutedInk)

                    Text(emptyTitle)
                        .font(.system(size: 31, weight: .black, design: .rounded))
                        .foregroundStyle(MeterTheme.accent(for: .agy))

                    Text(emptyDetail)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(MeterTheme.mutedInk)
                        .lineLimit(3)
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity, minHeight: 137, alignment: .leading)
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
