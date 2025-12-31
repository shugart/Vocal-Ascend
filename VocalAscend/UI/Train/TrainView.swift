import SwiftUI

struct TrainView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "music.note.list")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)

                Text("Today's Session")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Your personalized vocal workout is ready")
                    .foregroundStyle(.secondary)

                Button(action: startSession) {
                    Text("Start Training")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .navigationTitle("Train")
        }
    }

    private func startSession() {
        // TODO: Implement session start
    }
}

#Preview {
    TrainView()
}
