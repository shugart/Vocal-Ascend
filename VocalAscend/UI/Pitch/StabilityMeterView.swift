import SwiftUI

struct StabilityMeterView: View {
    let stability: Float // 0-100

    private var color: Color {
        if stability >= 70 {
            return .green
        } else if stability >= 40 {
            return .yellow
        } else {
            return .red
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color(.systemGray4), lineWidth: 8)
                    .frame(width: 80, height: 80)

                // Progress arc
                Circle()
                    .trim(from: 0, to: CGFloat(stability) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                // Value
                Text("\(Int(stability))")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Text("Stability")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HStack(spacing: 40) {
        StabilityMeterView(stability: 85)
        StabilityMeterView(stability: 55)
        StabilityMeterView(stability: 25)
    }
    .padding()
}
