import SwiftUI

struct QuotaCard: View {
    let window: QuotaWindowViewModel
    let isPrimary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(window.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(window.resetLineText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(window.remainingPercentText)
                    .font(.system(size: isPrimary ? 28 : 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(accentColor)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.09))
                    Capsule()
                        .fill(accentColor)
                        .frame(width: max(8, proxy.size.width * CGFloat(window.remainingPercent / 100)))
                }
            }
            .frame(height: isPrimary ? 10 : 8)

            HStack(spacing: 10) {
                metric(label: "已使用", value: window.usedPercentText)
                Divider()
                    .frame(height: 16)
                metric(label: "剩余", value: window.remainingPercentText)
                Spacer()
                healthBadge
            }
        }
        .padding(16)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private func metric(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .font(.system(size: 12))
    }

    private var healthBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(accentColor)
                .frame(width: 7, height: 7)
            Text(healthText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accentColor)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(accentColor.opacity(0.12), in: Capsule())
    }

    private var healthText: String {
        switch window.healthLevel {
        case .good:
            return "充足"
        case .warning:
            return "注意"
        case .danger:
            return "偏低"
        }
    }

    private var accentColor: Color {
        switch window.healthLevel {
        case .good:
            return Color(red: 0.08, green: 0.68, blue: 0.32)
        case .warning:
            return Color(red: 0.86, green: 0.58, blue: 0.02)
        case .danger:
            return Color(red: 0.9, green: 0.18, blue: 0.2)
        }
    }

    private var cardBackground: Color {
        if isPrimary {
            return accentColor.opacity(0.08)
        }
        return Color(nsColor: .controlBackgroundColor)
    }

    private var borderColor: Color {
        isPrimary ? accentColor.opacity(0.24) : Color.primary.opacity(0.08)
    }
}
