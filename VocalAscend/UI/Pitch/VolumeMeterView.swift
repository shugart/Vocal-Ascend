import SwiftUI

struct VolumeMeterView: View {
    let dbfs: Float // Typically -60 to 0

    private var normalizedLevel: Float {
        // Map -60 to 0 dBFS to 0 to 1
        let clamped = max(-60, min(0, dbfs))
        return (clamped + 60) / 60
    }

    private var color: Color {
        if dbfs > -6 {
            return .red // Clipping danger
        } else if dbfs > -12 {
            return .yellow // Loud
        } else {
            return .green // Good
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Vertical bar meter
            GeometryReader { geometry in
                let height = geometry.size.height
                let fillHeight = CGFloat(normalizedLevel) * height

                ZStack(alignment: .bottom) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(height: fillHeight)
                }
            }
            .frame(width: 24, height: 80)

            // dBFS value
            Text(String(format: "%.0f", dbfs))
                .font(.caption)
                .fontWeight(.medium)

            Text("dBFS")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HStack(spacing: 40) {
        VolumeMeterView(dbfs: -30)
        VolumeMeterView(dbfs: -15)
        VolumeMeterView(dbfs: -6)
    }
    .padding()
}
