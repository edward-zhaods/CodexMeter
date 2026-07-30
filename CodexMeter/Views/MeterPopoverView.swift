import SwiftUI

struct MeterPopoverView: View {
    @ObservedObject var appState: AppState

    private var heroWindow: QuotaWindowViewModel? {
        appState.fiveHourWindow ?? appState.weeklyWindow
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if let heroWindow {
                hero(window: heroWindow)
            } else {
                emptyHero
            }

            VStack(spacing: 10) {
                if let fiveHourWindow = appState.fiveHourWindow {
                    QuotaCard(window: fiveHourWindow, isPrimary: fiveHourWindow.id == heroWindow?.id)
                } else {
                    missingQuotaCard(title: "5 小时额度", message: "等待 Codex 返回短窗口数据")
                }

                if let weeklyWindow = appState.weeklyWindow {
                    QuotaCard(window: weeklyWindow, isPrimary: weeklyWindow.id == heroWindow?.id)
                } else {
                    missingQuotaCard(title: "周额度", message: "等待 Codex 返回周窗口数据")
                }

                ForEach(appState.otherWindows) { window in
                    QuotaCard(window: window, isPrimary: false)
                }
            }

            Divider()

            SettingsView(appState: appState)
        }
        .padding(20)
        .frame(width: 430)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Codex Meter")
                    .font(.system(size: 20, weight: .bold))
                Text(appState.statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusBadge
        }
    }

    private func hero(window: QuotaWindowViewModel) -> some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .stroke(heroAccent(for: window).opacity(0.16), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: CGFloat(window.remainingPercent / 100))
                    .stroke(
                        heroAccent(for: window),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text(window.remainingPercentText)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(heroAccent(for: window))
            }
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 8) {
                Text(window.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(window.resetLineText)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text("已使用 \(window.usedPercentText)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    heroAccent(for: window).opacity(0.14),
                    Color(nsColor: .controlBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(heroAccent(for: window).opacity(0.24), lineWidth: 1)
        )
    }

    private var emptyHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("额度同步中")
                .font(.system(size: 20, weight: .bold))
            Text("正在读取 Codex 官方 app-server 数据")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private var statusBadge: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(appState.isCachedDataStale ? "缓存" : "实时")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(statusColor.opacity(0.12), in: Capsule())
    }

    private func missingQuotaCard(title: String, message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func heroAccent(for window: QuotaWindowViewModel) -> Color {
        switch window.healthLevel {
        case .good:
            return Color(red: 0.08, green: 0.68, blue: 0.32)
        case .warning:
            return Color(red: 0.86, green: 0.58, blue: 0.02)
        case .danger:
            return Color(red: 0.9, green: 0.18, blue: 0.2)
        }
    }

    private var statusColor: Color {
        switch appState.statusColorName {
        case "green":
            return Color(red: 0.08, green: 0.68, blue: 0.32)
        case "orange":
            return Color(red: 0.86, green: 0.58, blue: 0.02)
        default:
            return Color(red: 0.9, green: 0.18, blue: 0.2)
        }
    }
}
