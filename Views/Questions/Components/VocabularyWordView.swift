import SwiftUI

struct VocabularyWordView: View {
    let wordNumber: Int
    let word: String
    let answer: String
    let editingAnswer: String
    let isLocked: Bool
    let isRecording: Bool
    let transcribedText: String
    let onWordTap: () -> Void
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onAnswerChanged: (String) -> Void
    let onLockAnswer: () -> Void
    let onUnlockAnswer: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Word Header
            HStack(alignment: .top, spacing: 16) {
                Text("\(wordNumber)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: .orange.opacity(0.3), radius: 4, x: 0, y: 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(word)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    // Define button integrated into header
                    Button(action: onWordTap) {
                        HStack(spacing: 6) {
                            Image(systemName: "book.fill")
                                .font(.caption)
                            Text("Define")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Answer Section using shared component
            AnswerSectionView(
                label: "Your Sentence:",
                placeholder: "Start recording or type your sentence...",
                editingAnswer: editingAnswer,
                isLocked: isLocked,
                isRecording: isRecording,
                transcribedText: transcribedText,
                onStartRecording: onStartRecording,
                onStopRecording: onStopRecording,
                onAnswerChanged: onAnswerChanged,
                onLockAnswer: onLockAnswer,
                onUnlockAnswer: onUnlockAnswer
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isLocked ? Color.green.opacity(0.4) : Color.clear,
                    lineWidth: isLocked ? 3 : 0
                )
        )
        .scaleEffect(isLocked ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isLocked)
    }
}
