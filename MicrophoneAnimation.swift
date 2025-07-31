import SwiftUI

struct MicrophoneAnimation: View {
    let isListening: Bool
    
    var body: some View {
        LottieView(
            animationName: "microphone-breathing",
            loopMode: .loop,
            animationSpeed: 0.8
        )
        .frame(width: 120, height: 120)
    }
}

#Preview {
    VStack(spacing: 40) {
        MicrophoneAnimation(isListening: false)
        Text("Microphone Animation")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
} 