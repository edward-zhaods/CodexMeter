import SwiftUI

struct SettingsView: View {
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

                    Toggle("低额度通知", isOn: $appState.lowQuotaNotificationsEnabled)
                        .toggleStyle(.checkbox)
                        .tint(MeterTheme.coral)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(MeterTheme.ink)

                    Button {
                        Task {
                            await appState.refresh()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(RetroButtonStyle(fill: MeterTheme.yellow, compact: true))
                    .help("刷新")
                }

                Rectangle()
                    .fill(MeterTheme.ink.opacity(0.16))
                    .frame(height: 1)

                HStack(spacing: 9) {
                    Text("悬浮样式")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(MeterTheme.mutedInk)

                    Spacer()

                    HStack(spacing: 5) {
                        ForEach(FloatingDisplayStyle.allCases) { style in
                            Button(style.title) {
                                appState.floatingDisplayStyle = style
                            }
                            .buttonStyle(
                                RetroButtonStyle(
                                    fill: appState.floatingDisplayStyle == style
                                        ? MeterTheme.pink
                                        : MeterTheme.paper,
                                    compact: true
                                )
                            )
                        }
                    }
                }

                HStack(alignment: .center, spacing: 8) {
                    infoBlock(
                        title: "Codex 路径",
                        value: appState.customCodexPath.isEmpty ? "自动查找" : appState.customCodexPath
                    )

                    Spacer(minLength: 6)

                    Button("选择") {
                        appState.chooseCodexExecutable()
                    }
                    .buttonStyle(RetroButtonStyle(compact: true))

                    Button("重置") {
                        appState.clearCustomCodexPath()
                    }
                    .buttonStyle(RetroButtonStyle(compact: true))
                    .disabled(appState.customCodexPath.isEmpty)
                }

                HStack(spacing: 7) {
                    Spacer()

                    Button("重连") {
                        Task {
                            await appState.reconnect()
                        }
                    }
                    .buttonStyle(RetroButtonStyle(fill: MeterTheme.blue, compact: true))

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
        guard let date = appState.lastSyncDate else { return "尚未同步" }
        return date.formatted(date: .omitted, time: .standard)
    }
}
