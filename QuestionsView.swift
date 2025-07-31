import FirebaseFirestore
import SwiftUI
import UIKit

struct QuestionsView: View {
    let articleId: String
    let practiceSession: ReadingSession? // Optional practice session data
    @StateObject private var viewModel = ArticleViewModel()
    @StateObject private var speechManager = SpeechRecognitionManager()
    @State private var isLoading = true
    @State private var selectedAnswers: [String: String] = [:] // questionText -> selected choice
    @State private var openEndedAnswers: [String: String] = [:] // questionText -> recorded answer
    @State private var editingAnswers: [String: String] = [:] // questionText -> currently editing answer
    @State private var lockedAnswers: Set<String> = [] // questionText -> locked status
    @State private var recordingQuestion: String? = nil // which question is currently being recorded
    @State private var showSubmitButton = false
    @State private var vocabularyWords: [String] = [] // Words to practice
    @State private var showingDictionary = false
    @State private var selectedWord = ""
    @State private var vocabularyAnswers: [String: String] = [:] // word -> recorded answer
    @State private var vocabularyEditingAnswers: [String: String] = [:] // word -> currently editing answer
    @State private var vocabularyLockedAnswers: Set<String> = [] // word -> locked status
    @State private var recordingVocabularyWord: String? = nil // which vocabulary word is currently being recorded
    
    // Computed property to get vocabulary words from practice session or article
    private var practiceVocabularyWords: [String] {
        if let session = practiceSession, !session.incorrectImportantWordsSet.isEmpty {
            // Use words that were mispronounced during practice
            return Array(session.incorrectImportantWordsSet).sorted()
        } else {
            // Use important words from the article if no practice session or perfect reading
            return getImportantWordsFromArticle()
        }
    }

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
                                
                                ForEach(Array(viewModel.multipleChoiceQuestions.enumerated()), id: \.element.id) { index, question in
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack(alignment: .top, spacing: 12) {
                                            Text("\(index + 1)")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .frame(width: 32, height: 32)
                                                .background(
                                                    Circle()
                                                        .fill(Color.blue)
                                                )
                                            
                                            Text(question.questionText)
                                                .font(.headline)
                                        }

                                        VStack(spacing: 8) {
                                            ForEach(Array(question.choices.enumerated()), id: \.element) { choiceIndex, choice in
                                                let choiceLabel = ["A", "B", "C", "D"][choiceIndex]
                                                HStack(alignment: .center, spacing: 12) {
                                                    Text(choiceLabel)
                                                        .font(.headline)
                                                        .foregroundColor(.blue)
                                                        .frame(width: 24, height: 24)
                                                        .background(
                                                            Circle()
                                                                .fill(Color.blue.opacity(0.1))
                                                        )
                                                    
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

                                ForEach(Array(viewModel.openEndedQuestions.enumerated()), id: \.element.id) { index, question in
                                    OpenEndedQuestionView(
                                        questionNumber: index + 1,
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
                        
                        // Vocabulary Practice Section
                        if !vocabularyWords.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "book.fill")
                                        .foregroundColor(.orange)
                                    Text("Vocabulary Practice")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal)
                                
                                Text("Use the given vocabulary word in a sentence")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 8) {
                                    ForEach(Array(vocabularyWords.enumerated()), id: \.offset) { index, word in
                                        VocabularyWordView(
                                            wordNumber: index + 1,
                                            word: word,
                                            answer: vocabularyAnswers[word] ?? "",
                                            editingAnswer: vocabularyEditingAnswers[word] ?? "",
                                            isLocked: vocabularyLockedAnswers.contains(word),
                                            isRecording: recordingVocabularyWord == word,
                                            transcribedText: speechManager.transcribedText,
                                            onWordTap: {
                                                selectedWord = word
                                                showDictionary(for: word)
                                            },
                                            onStartRecording: {
                                                startVocabularyRecording(for: word)
                                            },
                                            onStopRecording: {
                                                stopVocabularyRecording(for: word)
                                            },
                                            onAnswerChanged: { newAnswer in
                                                vocabularyEditingAnswers[word] = newAnswer
                                            },
                                            onLockAnswer: {
                                                lockVocabularyAnswer(for: word)
                                            },
                                            onUnlockAnswer: {
                                                unlockVocabularyAnswer(for: word)
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
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
            // Initialize vocabularyWords from practice session or article
            if let session = practiceSession, !session.incorrectImportantWordsSet.isEmpty {
                vocabularyWords = Array(session.incorrectImportantWordsSet).sorted()
            } else {
                vocabularyWords = getImportantWordsFromArticle()
            }
            // Add a slight delay to show loading spinner
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isLoading = false
            }
        }
        .onChange(of: speechManager.transcribedText) { oldValue, newText in
            if let recordingQuestion = recordingQuestion {
                editingAnswers[recordingQuestion] = newText
            }
            if let recordingVocabularyWord = recordingVocabularyWord {
                vocabularyEditingAnswers[recordingVocabularyWord] = newText
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
    
    // Vocabulary recording functions
    private func startVocabularyRecording(for word: String) {
        recordingVocabularyWord = word
        speechManager.startListening()
    }
    
    private func stopVocabularyRecording(for word: String) {
        recordingVocabularyWord = nil
        speechManager.stopListening()
        // Save the transcribed text as the answer
        vocabularyAnswers[word] = vocabularyEditingAnswers[word] ?? ""
    }
    
    private func lockVocabularyAnswer(for word: String) {
        vocabularyLockedAnswers.insert(word)
        // Save the current editing answer as the final answer
        vocabularyAnswers[word] = vocabularyEditingAnswers[word] ?? ""
    }
    
    private func unlockVocabularyAnswer(for word: String) {
        vocabularyLockedAnswers.remove(word)
    }
    
    // Get important words from the article for vocabulary practice
    private func getImportantWordsFromArticle() -> [String] {
        guard let session = practiceSession else { return [] }
        
        // Get all important words from the article
        let importantWords = session.paragraph.words.filter { word in
            WordClassifier.isImportantWord(word)
        }
        
        // Remove duplicates and common words, then take up to 5 words
        let uniqueImportantWords = Array(Set(importantWords))
            .filter { word in
                // Filter out very common words
                let commonWords = ["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "is", "are", "was", "were", "be", "been", "have", "has", "had", "do", "does", "did", "will", "would", "could", "should", "may", "might", "can", "this", "that", "these", "those", "it", "its", "they", "them", "their", "we", "you", "he", "she", "his", "her", "my", "your", "our", "us", "me", "him", "i"]
                return !commonWords.contains(word.lowercased())
            }
            .prefix(5)
            .sorted()
        
        return Array(uniqueImportantWords)
    }
    
    // Show Apple's built-in dictionary for a word
    private func showDictionary(for word: String) {
        let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
        if UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: cleanWord) {
            let dictionaryVC = UIReferenceLibraryViewController(term: cleanWord)
            
            // Present the dictionary view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                // Find the topmost view controller
                var topViewController = rootViewController
                while let presentedViewController = topViewController.presentedViewController {
                    topViewController = presentedViewController
                }
                
                topViewController.present(dictionaryVC, animated: true)
            }
        } else {
            // Word not found in dictionary - could show an alert or just ignore
            print("No dictionary definition found for: \(cleanWord)")
        }
    }
}

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
                        
                        TextEditor(text: Binding(
                            get: { editingAnswer },
                            set: { onAnswerChanged($0) }
                        ))
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .disabled(isLocked)
                        
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
                    // Show Definition and Record Sentence buttons side by side
                    HStack(spacing: 8) {
                        Button(action: onWordTap) {
                            HStack {
                                Image(systemName: "book.fill")
                                Text("Definition")
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                        }
                        .frame(maxWidth: .infinity)
                        
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
                        .frame(maxWidth: .infinity)
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

struct OpenEndedQuestionView: View {
    let questionNumber: Int
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
            HStack(alignment: .top, spacing: 12) {
                Text("\(questionNumber)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.blue)
                    )
                
                Text(question.questionText)
                    .font(.headline)
            }
            
            VStack(spacing: 8) {
                // Answer display/editing area
                if !editingAnswer.isEmpty || isRecording {
                    VStack(alignment: .leading, spacing: 8) {
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
                            .foregroundColor(isLocked ? .green : .blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isLocked ? Color.green : Color.blue, lineWidth: 1)
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                } else if !isRecording {
                    // Only show Record Answer button if not recording and no answer
                    Button(action: {
                        onStartRecording()
                    }) {
                        HStack {
                            Image(systemName: "mic.fill")
                            Text("Record Answer")
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                    }
                    .frame(maxWidth: .infinity)
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
