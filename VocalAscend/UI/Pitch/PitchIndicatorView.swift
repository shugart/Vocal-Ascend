import SwiftUI

struct PitchIndicatorView: View {
    let centsOffset: Float
    let tolerance: Float

    private var normalizedOffset: CGFloat {
        // Clamp to -50...+50 cents range for display
        let clamped = max(-50, min(50, centsOffset))
        return CGFloat(clamped) / 50.0
    }

    private var indicatorColor: Color {
        if abs(centsOffset) <= tolerance {
            return .green
        } else if abs(centsOffset) <= tolerance * 2 {
            return .yellow
        } else {
            return .red
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let centerX = width / 2
            let indicatorX = centerX + (normalizedOffset * centerX * 0.8)

            ZStack {
                // Background track
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(height: 40)

                // In-tune zone
                let toleranceWidth = (CGFloat(tolerance) / 50.0) * centerX * 0.8 * 2
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.green.opacity(0.2))
                    .frame(width: toleranceWidth, height: 32)

                // Center line
                Rectangle()
                    .fill(Color.green)
                    .frame(width: 3, height: 50)

                // Indicator
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 24, height: 24)
                    .shadow(radius: 2)
                    .position(x: indicatorX, y: geometry.size.height / 2)

                // Scale markers
                HStack {
                    Text("♭")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("♯")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(height: 60)
    }
}

#Preview {
    VStack(spacing: 20) {
        PitchIndicatorView(centsOffset: 0, tolerance: 25)
        PitchIndicatorView(centsOffset: 15, tolerance: 25)
        PitchIndicatorView(centsOffset: -30, tolerance: 25)
        PitchIndicatorView(centsOffset: 45, tolerance: 25)
    }
    .padding()
}
