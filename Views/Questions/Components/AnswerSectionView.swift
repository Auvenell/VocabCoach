import SwiftUI

struct AnswerSectionView: View {
    let label: String
    let placeholder: String
    let editingAnswer: String
    let isLocked: Bool
    let isRecording: Bool
    let transcribedText: String
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onAnswerChanged: (String) -> Void
    let onLockAnswer: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            if !editingAnswer.isEmpty || isRecording {
                // Answer Display/Editing Area
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(label)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Lock Status Indicator
                        if isLocked {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("Locked")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.green.opacity(0.1))
                            )
                        }
                    }
                    
                    // Text Editor with Enhanced Styling
                    CustomTextEditor(
                        text: Binding(
                            get: { editingAnswer },
                            set: { onAnswerChanged($0) }
                        ),
                        placeholder: placeholder,
                        isDisabled: isLocked
                    )
                    .frame(minHeight: 100)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isLocked ? Color.green.opacity(0.3) : Color(.systemGray4),
                                        lineWidth: isLocked ? 2 : 1
                                    )
                            )
                    )
                    .opacity(isLocked ? 0.8 : 1.0)
                    
                    // Enhanced Recording Status
                    if isRecording {
                        HStack(spacing: 12) {
                            // Animated Recording Indicator
                            HStack(spacing: 8) {
                                Image(systemName: "mic.fill")
                                    .foregroundColor(.red)
                                    .scaleEffect(1.2)
                                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isRecording)
                                
                                Text("Recording...")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                            }
                            
                            Spacer()
                            
                            // Live Transcription Preview
                            if !transcribedText.isEmpty {
                                Text(transcribedText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                                    .lineLimit(2)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
                
                // Enhanced Action Buttons
                HStack(spacing: 16) {
                    if isRecording {
                        // Stop Recording Button
                        Button(action: onStopRecording) {
                            HStack(spacing: 8) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Stop Recording")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: .red.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        // Re-record Button
                        Button(action: {
                            onAnswerChanged("")
                            onStartRecording()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Re-record")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange, lineWidth: 2)
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange.opacity(0.05))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isLocked)
                        .opacity(isLocked ? 0.5 : 1.0)
                    }
                    
                    // Lock Button (only shown when not locked)
                    if !isLocked {
                        Button(action: onLockAnswer) {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.open.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Lock Answer")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.05))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            } else if !isRecording {
                // Initial Record Button
                Button(action: onStartRecording) {
                    HStack(spacing: 12) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Record Answer")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Preview for locked state
        AnswerSectionView(
            label: "Your Answer:",
            placeholder: "Start recording or type your answer...",
            editingAnswer: "This is a sample answer that is locked.",
            isLocked: true,
            isRecording: false,
            transcribedText: "",
            onStartRecording: {},
            onStopRecording: {},
            onAnswerChanged: { _ in },
            onLockAnswer: {}
        )
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        
        // Preview for recording state
        AnswerSectionView(
            label: "Your Sentence:",
            placeholder: "Start recording or type your sentence...",
            editingAnswer: "This is a sample sentence being recorded.",
            isLocked: false,
            isRecording: true,
            transcribedText: "This is a sample sentence being recorded.",
            onStartRecording: {},
            onStopRecording: {},
            onAnswerChanged: { _ in },
            onLockAnswer: {}
        )
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        
        // Preview for empty state
        AnswerSectionView(
            label: "Your Answer:",
            placeholder: "Start recording or type your answer...",
            editingAnswer: "",
            isLocked: false,
            isRecording: false,
            transcribedText: "",
            onStartRecording: {},
            onStopRecording: {},
            onAnswerChanged: { _ in },
            onLockAnswer: {}
        )
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    .padding()
}
