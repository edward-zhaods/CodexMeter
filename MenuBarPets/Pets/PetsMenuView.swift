import AppKit
import SwiftUI

extension Notification.Name {
    static let petsMenuSelect = Notification.Name("petsMenuSelect")
}

struct PetsMenuView: View {
    @ObservedObject var store: PetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(PetKind.allCases) { kind in
                Button {
                    NotificationCenter.default.post(name: .petsMenuSelect, object: kind.rawValue)
                } label: {
                    row(kind)
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
        .frame(width: 308)
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

    private func row(_ kind: PetKind) -> some View {
        let mood = store.moods[kind] ?? .idle
        return HStack(spacing: 10) {
            rowIcon(kind)
                .frame(width: 22, height: 22)

            Text(kind.menuTitle(vacation: store.claudeOnVacation) + "：")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PetPalette.text)
                .lineLimit(1)

            Spacer(minLength: 8)

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

    @ViewBuilder
    private func rowIcon(_ kind: PetKind) -> some View {
        if let image = PetArt.menuIcon(kind) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            Image(systemName: kind.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(kind.accent)
        }
    }
}
