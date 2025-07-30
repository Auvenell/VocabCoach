import FirebaseFirestore
import SwiftUI

struct QuestionsView: View {
    let articleId: String
    @StateObject private var viewModel = ArticleViewModel()
    @StateObject private var speechManager = SpeechRecognitionManager()
    @State private var isLoading = true
    @State private var selectedAnswers: [String: String] = [:] // questionText -> selected choice
    @State private var openEndedAnswers: [String: String] = [:] // questionText -> recorded answer
    @State private var editingAnswers: [String: String] = [:] // questionText -> currently editing answer
    @State private var lockedAnswers: Set<String> = [] // questionText -> locked status
    @State private var recordingQuestion: String? = nil // which question is currently being recorded
    @State private var showSubmitButton = false

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading questions...")
            } else if viewModel.openEndedQuestions.isEmpty && viewModel.multipleChoiceQuestions.isEmpty {
                Text("No questions found for this article.")
                    .foregroundColor(.gray)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        if !viewModel.multipleChoiceQuestions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Multiple Choice Questions")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(viewModel.multipleChoiceQuestions) { question in
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text(question.questionText)
                                            .font(.headline)
                                            .padding(.horizontal)

                                        VStack(spacing: 8) {
                                            ForEach(question.choices, id: \.self) { choice in
                                                Button(action: {
                                                    selectedAnswers[question.questionText] = choice
                                                    showSubmitButton = true
                                                }) {
                                                    HStack {
                                                        Text(choice)
                                                            .foregroundColor(.primary)
                                                            .multilineTextAlignment(.leading)
                                                        Spacer()
                                                        if selectedAnswers[question.questionText] == choice {
                                                            Image(systemName: "checkmark.circle.fill")
                                                                .foregroundColor(.blue)
                                                        }
                                                    }
                                                    .padding()
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(selectedAnswers[question.questionText] == choice ?
                                                                Color.blue.opacity(0.1) : Color(.systemGray6))
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 8)
                                                                    .stroke(selectedAnswers[question.questionText] == choice ?
                                                                        Color.blue : Color.clear, lineWidth: 2)
                                                            )
                                                    )
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                    .padding(.vertical, 8)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                    .padding(.horizontal)
                                }
                            }
                        }

                        if !viewModel.openEndedQuestions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Open-Ended Questions")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(viewModel.openEndedQuestions) { question in
                                    OpenEndedQuestionView(
                                        question: question,
                                        answer: openEndedAnswers[question.questionText] ?? "",
                                        editingAnswer: editingAnswers[question.questionText] ?? "",
                                        isLocked: lockedAnswers.contains(question.questionText),
                                        isRecording: recordingQuestion == question.questionText,
                                        transcribedText: speechManager.transcribedText,
                                        onStartRecording: {
                                            startRecording(for: question.questionText)
                                        },
                                        onStopRecording: {
                                            stopRecording(for: question.questionText)
                                        },
                                        onAnswerChanged: { newAnswer in
                                            editingAnswers[question.questionText] = newAnswer
                                        },
                                        onLockAnswer: {
                                            lockAnswer(for: question.questionText)
                                        },
                                        onUnlockAnswer: {
                                            unlockAnswer(for: question.questionText)
                                        }
                                    )
                                }
                            }
                        }

                        if showSubmitButton || !openEndedAnswers.isEmpty {
                            Button(action: {
                                // TODO: Handle submit action
                                print("Selected answers: \(selectedAnswers)")
                                print("Open-ended answers: \(openEndedAnswers)")
                            }) {
                                Text("Submit Answers")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Questions")
        .onAppear {
            viewModel.fetchQuestions(for: articleId)
            // Add a slight delay to show loading spinner
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isLoading = false
            }
        }
        .onChange(of: speechManager.transcribedText) { oldValue, newText in
            if let recordingQuestion = recordingQuestion {
                editingAnswers[recordingQuestion] = newText
            }
        }
    }
    
    private func startRecording(for questionText: String) {
        recordingQuestion = questionText
        speechManager.startListening()
    }
    
    private func stopRecording(for questionText: String) {
        recordingQuestion = nil
        speechManager.stopListening()
        // Save the transcribed text as the answer
        openEndedAnswers[questionText] = editingAnswers[questionText] ?? ""
    }
    
    private func lockAnswer(for questionText: String) {
        lockedAnswers.insert(questionText)
        // Save the current editing answer as the final answer
        openEndedAnswers[questionText] = editingAnswers[questionText] ?? ""
    }
    
    private func unlockAnswer(for questionText: String) {
        lockedAnswers.remove(questionText)
    }
}

struct OpenEndedQuestionView: View {
    let question: ComprehensionQuestion
    let answer: String
    let editingAnswer: String
    let isLocked: Bool
    let isRecording: Bool
    let transcribedText: String
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onAnswerChanged: (String) -> Void
    let onLockAnswer: () -> Void
    let onUnlockAnswer: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question.questionText)
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                // Answer display/editing area
                VStack(alignment: .leading, spacing: 8) {
                    if !editingAnswer.isEmpty {
                        Text("Your Answer:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: Binding(
                            get: { editingAnswer },
                            set: { onAnswerChanged($0) }
                        ))
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .disabled(isLocked)
                    }
                    
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
                        .padding(.horizontal)
                    }
                }
                
                // Action buttons
                HStack(spacing: 12) {
                    // Record/Stop button
                    Button(action: {
                        if isRecording {
                            onStopRecording()
                        } else {
                            onStartRecording()
                        }
                    }) {
                        HStack {
                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            Text(isRecording ? "Stop Recording" : "Record Answer")
                        }
                        .foregroundColor(isRecording ? .red : .blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isRecording ? Color.red : Color.blue, lineWidth: 1)
                        )
                    }
                    .disabled(isLocked)
                    
                    // Re-record button
                    if !editingAnswer.isEmpty && !isRecording {
                        Button(action: {
                            onAnswerChanged("")
                            onStartRecording()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Re-record")
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.orange, lineWidth: 1)
                            )
                        }
                        .disabled(isLocked)
                    }
                    
                    Spacer()
                    
                    // Lock/Unlock button
                    if !editingAnswer.isEmpty {
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
                            .foregroundColor(isLocked ? .green : .blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isLocked ? Color.green : Color.blue, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isLocked ? Color.green : Color.clear, lineWidth: 2)
        )
    }
}
