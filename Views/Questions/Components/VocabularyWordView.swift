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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(wordNumber)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.orange)
                    )
                
                Text(word)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
            
            VStack(spacing: 8) {
                // Answer display/editing area
                if !editingAnswer.isEmpty || isRecording {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Sentence:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        CustomTextEditor(
                            text: Binding(
                                get: { editingAnswer },
                                set: { onAnswerChanged($0) }
                            ),
                            placeholder: "Start recording or type your sentence...",
                            isDisabled: isLocked
                        )
                        .frame(minHeight: 80)
                        
                        // Recording status
                        if isRecording {
                            HStack {
                                Image(systemName: "mic.fill")
                                    .foregroundColor(.red)
                                    .scaleEffect(1.2)
                                Text("Recording... \(transcribedText)")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                    // Action buttons: Stop/Re-record & Lock/Unlock side by side
                    HStack(spacing: 12) {
                        if isRecording {
                            Button(action: {
                                onStopRecording()
                            }) {
                                HStack {
                                    Image(systemName: "stop.fill")
                                    Text("Stop")
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.red)
                                )
                            }
                        } else {
                            Button(action: {
                                onAnswerChanged("")
                                onStartRecording()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Re-record")
                                }
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.orange, lineWidth: 1)
                                )
                            }
                            .disabled(isLocked)
                        }
                        
                        Button(action: {
                            if isLocked {
                                onUnlockAnswer()
                            } else {
                                onLockAnswer()
                            }
                        }) {
                            HStack {
                                Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                                Text(isLocked ? "Unlock" : "Lock")
                            }
                            .foregroundColor(isLocked ? .green : .orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isLocked ? Color.green : Color.orange, lineWidth: 1)
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                } else if !isRecording {
                    // Show Define button on the left and Record Sentence button centered
                    HStack(spacing: 4) {
                        Button(action: onWordTap) {
                            HStack {
                                Image(systemName: "book.fill")
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            onStartRecording()
                        }) {
                            HStack {
                                Image(systemName: "mic.fill")
                                Text("Record Sentence")
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.orange, lineWidth: 1)
                            )
                        }
                        
                        Spacer()
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isLocked ? Color.green : Color.clear, lineWidth: 2)
        )
    }
}
