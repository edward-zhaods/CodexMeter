import SwiftUI

struct QuotaCard: View {
    let window: QuotaWindowViewModel
    let isPrimary: Bool

    private var filledSegments: Int {
        Int(ceil(window.remainingPercent / 10))
    }

    var body: some View {
        RetroCard(fill: MeterTheme.fill(for: window.kind)) {
            VStack(alignment: .leading, spacing: 7) {
                Text(window.title.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(MeterTheme.mutedInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(window.remainingPercentText)
                    .font(.system(size: isPrimary ? 29 : 27, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(MeterTheme.ink)
                    .lineLimit(1)

                segmentedProgress

                HStack(spacing: 5) {
                    Circle()
                        .fill(MeterTheme.healthColor(for: window.healthLevel))
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(MeterTheme.ink, lineWidth: 0.9))

                    Text(healthText)
                        .fontWeight(.bold)

                    Spacer(minLength: 2)

                    Text("用 \(window.usedPercentText)")
                        .lineLimit(1)
                }
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(MeterTheme.ink)

                Text(window.resetLineText)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(MeterTheme.mutedInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
        }
    }

    private var segmentedProgress: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<10, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(index < filledSegments ? MeterTheme.coral : MeterTheme.idleBlock.opacity(0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .stroke(
                                index < filledSegments ? MeterTheme.ink : Color.clear,
                                lineWidth: 0.8
                            )
                    )
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 9)
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
}
