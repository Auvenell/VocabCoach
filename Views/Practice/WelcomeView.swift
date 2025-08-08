import SwiftUI

struct WelcomeView: View {
    let onStartPractice: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            // Microphone animation
            MicrophoneAnimation(isListening: false)

            Text("Welcome to Vocab Coach")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Improve your English pronunciation and fluency by reading aloud and getting real-time feedback.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button(action: onStartPractice) {
                Text("Start Practice")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    WelcomeView {
        print("Start practice tapped")
    }
}
