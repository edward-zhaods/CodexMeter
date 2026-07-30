import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                infoBlock(title: "最后同步", value: lastSyncText)

                Spacer()

                Button {
                    Task {
                        await appState.refresh()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
                .frame(width: 34, height: 34)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .help("刷新")
            }

            HStack(spacing: 12) {
                Toggle(isOn: $appState.lowQuotaNotificationsEnabled) {
                    Label("低额度通知", systemImage: "bell.badge")
                        .font(.system(size: 13, weight: .medium))
                }
                .toggleStyle(.checkbox)

                Spacer()

                Button("重连") {
                    Task {
                        await appState.reconnect()
                    }
                }

                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
            }

            HStack(spacing: 12) {
                Label("悬浮样式", systemImage: "circle.dashed")
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                Picker("悬浮样式", selection: $appState.floatingDisplayStyle) {
                    ForEach(FloatingDisplayStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 148)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    infoBlock(title: "Codex 路径", value: appState.customCodexPath.isEmpty ? "自动查找" : appState.customCodexPath)
                    Spacer()
                    Button("选择") {
                        appState.chooseCodexExecutable()
                    }
                    Button("重置") {
                        appState.clearCustomCodexPath()
                    }
                    .disabled(appState.customCodexPath.isEmpty)
                }
            }
        }
        .font(.system(size: 13))
    }

    private func infoBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var lastSyncText: String {
        guard let date = appState.lastSyncDate else { return "尚未同步" }
        return date.formatted(date: .omitted, time: .standard)
    }
}
