import SwiftUI

struct PracticeSessionView: View {
    let session: ReadingSession
    let transcribedText: String
    let scrollTargetIndex: Int?
    let isListening: Bool
    let onWordTap: (String) -> Void
    let onStartStopPractice: () -> Void
    let onResetSession: () -> Void
    let onResetToSentenceStart: () -> Void
    let onSkipCurrentWord: () -> Void
    let onSkipToEnd: () -> Void
    let onContinueToQuestions: () -> Void
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            VStack(spacing: 20) {
                ScrollView {
                    TappableTextView(
                        paragraph: session.paragraph,
                        wordAnalyses: session.wordAnalyses,
                        onWordTap: onWordTap,
                        scrollTargetIndex: scrollTargetIndex
                    )
                }
                .frame(height: 300)
                .onChange(of: scrollTargetIndex) { _, idx in
                    if let idx = idx {
                        withAnimation {
                            scrollProxy.scrollTo(idx, anchor: .top)
                        }
                    }
                }

                // Transcription view
                TranscriptionView(
                    transcribedText: transcribedText
                )

                // Control buttons
                VStack(spacing: 12) {
                    // Start/Stop Reading button (prominent)
                    Button(action: onStartStopPractice) {
                        HStack(spacing: 12) {
                            Image(systemName: isListening ? "waveform.circle.fill" : "play.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                                .shadow(color: isListening ? .blue.opacity(0.7) : .clear, radius: 10, x: 0, y: 0)
                                .scaleEffect(isListening ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: isListening)
                            Text(isListening ? "Stop" : "Start Reading")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isListening ? Color.red : Color.green)
                        .cornerRadius(16)
                        .shadow(color: isListening ? .blue.opacity(0.5) : .clear, radius: 10, x: 0, y: 0)
                        .opacity(session.isCompleted ? 0.5 : 1.0)
                    }
                    .accessibilityLabel(isListening ? "Stop Listening" : "Start Reading")
                    .disabled(session.isCompleted)

                    // Reset button - changes behavior based on completion state
                    Button(action: {
                        if session.isCompleted {
                            onResetSession()
                        } else {
                            onResetToSentenceStart()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: session.isCompleted ? "arrow.counterclockwise" : "arrow.clockwise")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                            Text(session.isCompleted ? "Start Over" : "Start from beginning of sentence")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    // Skip Word and Skip to End buttons
                    if !session.isCompleted, session.currentWord != nil {
                        HStack(spacing: 8) {
                            Button(action: onSkipCurrentWord) {
                                HStack(spacing: 8) {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.orange)
                                    Text("Skip Word")
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            Button(action: onSkipToEnd) {
                                HStack(spacing: 8) {
                                    Image(systemName: "forward.end.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.purple)
                                    Text("Skip to End")
                                        .font(.subheadline)
                                        .foregroundColor(.purple)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(.top, 16)

                // Progress indicator
                if session.totalWords > 0 {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Progress:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(session.correctWords)/\(session.totalWords) words")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        ProgressView(value: session.accuracy)
                            .progressViewStyle(LinearProgressViewStyle())
                            .accentColor(session.accuracy > 0.8 ? .green : session.accuracy > 0.6 ? .orange : .red)

                        // Current word indicator
                        if let currentWord = session.currentWord {
                            HStack {
                                Text("Current word:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(currentWord)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                Spacer()
                                Text("Word \(session.currentWordIndex + 1) of \(session.totalWords)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else if session.isCompleted {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("✅ Completed!")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                    Spacer()
                                }

                                let reviewWords = session.wordsToReview
                                if !reviewWords.isEmpty {
                                    Text("Words to practice:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    ScrollView {
                                        VStack(alignment: .leading, spacing: 4) {
                                            ForEach(reviewWords, id: \.self) { word in
                                                HStack {
                                                    Text("• \(word)")
                                                        .font(.caption)
                                                        .foregroundColor(.red)
                                                    Spacer()
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxHeight: 120)
                                }
                                // Trigger navigation to questions when completed
                                Button(action: onContinueToQuestions) {
                                    HStack {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .font(.title2)
                                        Text("Continue to Questions")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .padding(.horizontal, 24)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                    .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                                .padding(.top, 16)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }

                Spacer()
            }
        }
    }
}
