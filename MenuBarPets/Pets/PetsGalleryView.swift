import AppKit
import SwiftUI

struct PetsGalleryView: View {
    @ObservedObject var store: PetStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    cardGrid
                }
                .padding(22)
                .frame(maxWidth: 1180)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.045, blue: 0.10),
                    Color(red: 0.07, green: 0.05, blue: 0.14),
                    Color(red: 0.03, green: 0.04, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(PetKind.cursor.accent.opacity(0.16))
                .frame(width: 280, height: 280)
                .blur(radius: 40)
                .offset(x: 360, y: -220)
            Circle()
                .fill(PetKind.gemini.accent.opacity(0.12))
                .frame(width: 240, height: 240)
                .blur(radius: 36)
                .offset(x: -380, y: 260)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            mark
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("MenuBar Pets")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(PetPalette.text)
                    Text("v0.1")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PetPalette.text.opacity(0.9))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
                }
                Text("四位 AI 助手 · 常驻你的 Mac 菜单栏")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PetPalette.muted)
                chips
            }
            Spacer(minLength: 0)
        }
    }

    private var mark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.35))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PetKind.codex.accent.opacity(0.8), lineWidth: 1.4)
            menuGlyph(.codex, side: 40)
        }
        .frame(width: 58, height: 58)
        .shadow(color: PetKind.codex.accent.opacity(0.35), radius: 10)
    }

    private var chips: some View {
        HStack(spacing: 14) {
            chip("实时状态", color: PetKind.codex.accent)
            chip("生动动画", color: PetKind.cursor.accent)
            chip("角色鲜明", color: PetKind.gemini.accent)
            chip("像素收藏宠物", color: PetKind.claude.accent)
        }
    }

    private func chip(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "diamond.fill")
                .font(.system(size: 8))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PetPalette.muted)
        }
    }

    private var cardGrid: some View {
        TimelineView(.periodic(from: .now, by: reduceMotion ? 86_400 : 0.7)) { timeline in
            let frame = frameIndex(at: timeline.date)
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ],
                spacing: 16
            ) {
                ForEach(PetKind.allCases) { kind in
                    petCard(kind, frame: frame)
                }
            }
        }
    }

    private func frameIndex(at date: Date) -> Int {
        if reduceMotion {
            return 0
        }
        let ticks = Int((date.timeIntervalSinceReferenceDate / 0.7).rounded(.down))
        return PetArt.normalizedFrame(ticks)
    }

    private func petCard(_ kind: PetKind, frame: Int) -> some View {
        let mood = store.moods[kind] ?? .idle
        let vacation = store.claudeOnVacation
        let selected = store.focusedPet == kind
        let livePose = PetArt.pose(for: mood)
        return VStack(alignment: .leading, spacing: 10) {
            cardHeader(kind, mood: mood, vacation: vacation)
            HStack(alignment: .center, spacing: 10) {
                hero(kind, pose: livePose, frame: frame)
                    .frame(maxWidth: .infinity)
                    .frame(height: 210)
                VStack(spacing: 8) {
                    strip(kind, pose: .idle, active: livePose == .idle, frame: frame)
                    strip(kind, pose: .working, active: livePose == .working, frame: frame)
                }
                .frame(maxWidth: .infinity)
            }
            Text(store.detailLine(kind))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(PetPalette.muted)
                .lineLimit(1)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(PetPalette.card.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(kind.accent.opacity(selected || mood == .working ? 0.95 : 0.45), lineWidth: selected ? 1.8 : 1.2)
        )
        .shadow(color: kind.accent.opacity(mood == .working && !reduceMotion ? 0.38 : 0.16), radius: mood == .working ? 16 : 8)
        .opacity(mood == .offline ? 0.72 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture {
            store.focusedPet = kind
        }
    }

    private func cardHeader(_ kind: PetKind, mood: PetMood, vacation: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            menuGlyph(kind, side: 22)
                .frame(width: 22, height: 22)
            Text(kind.menuTitle(vacation: vacation))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(PetPalette.text)
                .lineLimit(1)
                .layoutPriority(1)
            Rectangle()
                .fill(PetPalette.muted.opacity(0.35))
                .frame(width: 1, height: 14)
            Text(kind.subtitle(vacation: vacation))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PetPalette.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Spacer(minLength: 6)
            if kind == .claude {
                Button(vacation ? "结束休假" : "开始休假") {
                    store.claudeOnVacation.toggle()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(kind.accent)
            }
            Text(mood.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(mood.pillText)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(mood.pillFill, in: Capsule())
        }
    }

    private func hero(_ kind: PetKind, pose: PetPose, frame: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.28))
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(kind.accent.opacity(0.28), lineWidth: 1)
            sprite(kind, pose: pose, index: frame)
                .padding(16)
        }
    }

    private func strip(_ kind: PetKind, pose: PetPose, active: Bool, frame: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(pose == .idle ? "闲着" : "工作中")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(active ? kind.accent : PetPalette.muted)
            HStack(spacing: 4) {
                ForEach(0..<PetArt.frameCount, id: \.self) { index in
                    frameCell(
                        kind,
                        pose: pose,
                        index: index,
                        highlighted: active && index == frame
                    )
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.22))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(active ? kind.accent.opacity(0.9) : Color.white.opacity(0.06), lineWidth: active ? 1.6 : 1)
        )
        .shadow(color: active ? kind.accent.opacity(0.28) : .clear, radius: 8)
    }

    private func frameCell(_ kind: PetKind, pose: PetPose, index: Int, highlighted: Bool) -> some View {
        ZStack {
            sprite(kind, pose: pose, index: index)
                .padding(3)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(highlighted ? kind.accent.opacity(0.16) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(highlighted ? kind.accent : Color.clear, lineWidth: 1.4)
        )
    }

    @ViewBuilder
    private func sprite(_ kind: PetKind, pose: PetPose, index: Int) -> some View {
        if let image = PetArt.frame(kind, pose: pose, index: index) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func menuGlyph(_ kind: PetKind, side: CGFloat) -> some View {
        if let image = PetArt.menuIcon(kind) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: side, height: side)
        } else {
            Image(systemName: kind.symbolName)
                .font(.system(size: side * 0.62, weight: .bold))
                .foregroundStyle(kind.accent)
                .frame(width: side, height: side)
        }
    }
}
