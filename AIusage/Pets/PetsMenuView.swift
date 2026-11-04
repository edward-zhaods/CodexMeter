import AppKit
import SwiftUI

extension Notification.Name {
    static let petsMenuSelect = Notification.Name("petsMenuSelect")
}

struct PetsMenuView: View {
    @ObservedObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.5, paused: reduceMotion)) { timeline in
            let frame = reduceMotion
                ? 0
                : Int(timeline.date.timeIntervalSinceReferenceDate / 0.5) % PetPixels.frameCount
            menu(frame: frame)
        }
    }

    private func menu(frame: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(PetKind.allCases) { kind in
                Button {
                    NotificationCenter.default.post(name: .petsMenuSelect, object: kind.rawValue)
                } label: {
                    row(kind, frame: frame)
                }
                .buttonStyle(.plain)
            }

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
                .padding(.vertical, 8)

            HStack {
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Text("退出")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PetPalette.text)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q", modifiers: .command)

                Spacer()

                Text("⌘Q")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(PetPalette.muted)
            }
        }
        .padding(14)
        .frame(width: 392)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.09, green: 0.10, blue: 0.16).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .preferredColorScheme(.dark)
    }

    private func row(_ kind: PetKind, frame: Int) -> some View {
        let mood = appState.petMoods[kind] ?? .idle
        let pose: PetPose = mood == .working ? .working : .idle
        let shownFrame = mood == .working ? frame : 0
        let sprite = PetPixels.image(for: kind, pose: pose, frame: shownFrame)
        let glance = appState.quotaGlance(for: kind)
        return HStack(spacing: 8) {
            Image(nsImage: sprite)
                .resizable()
                .interpolation(.none)
                .frame(width: sprite.size.width * 2, height: sprite.size.height * 2)
                .opacity(mood == .offline ? 0.4 : 1)

            Text(kind.menuTitle(vacation: false) + "：")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PetPalette.text)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 1) {
                Text(glance.primary)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(PetPalette.text)
                    .lineLimit(1)
                if let secondary = glance.secondary {
                    Text(secondary)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(PetPalette.muted)
                        .lineLimit(1)
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 12)

            Text(mood.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(mood.pillText)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(mood.pillFill, in: Capsule())
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}
