import SwiftUI
import FirebaseAuth

struct ReadingPracticeView: View {
    @StateObject private var speechManager = SpeechRecognitionManager()
    @StateObject private var ttsManager = TextToSpeechManager()
    @StateObject private var dataManager = ParagraphDataManager()
    @EnvironmentObject var headerState: HeaderState

    @State private var currentSession: ReadingSession?
    @State private var selectedParagraph: PracticeParagraph?
    @Binding var showingParagraphSelector: Bool
    @State private var showingResults = false
    @State private var feedbackMessage = ""
    @State private var scrollTargetIndex: Int? = nil
    @State private var showQuestions = false


    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let session = currentSession {
                    PracticeSessionView(
                        session: session,
                        transcribedText: speechManager.transcribedText,
                        scrollTargetIndex: scrollTargetIndex,
                        isListening: speechManager.isListening,
                        onWordTap: { word in
                            handleWordTap(word)
                        },
                        onStartStopPractice: {
                            if speechManager.isListening {
                                stopPractice()
                            } else {
                                startPractice()
                            }
                        },
                        onResetSession: {
                            resetSession()
                        },
                        onResetToSentenceStart: {
                            resetToSentenceStart()
                        },
                        onSkipCurrentWord: {
                            skipCurrentWord()
                        },
                        onSkipToEnd: {
                            skipToEnd()
                        },
                        onContinueToQuestions: {
                            showQuestions = true
                        }
                    )
                } else {
                    WelcomeView {
                        showingParagraphSelector = true
                    }
                }
            }
            .padding()
            .navigationDestination(isPresented: $showQuestions) {
                QuestionsView(
                    articleId: selectedParagraph?.id ?? "",
                    practiceSession: currentSession
                )
                .environmentObject(headerState)
            }
            .sheet(isPresented: $showingParagraphSelector) {
                ParagraphSelectorView(
                    dataManager: dataManager,
                    selectedParagraph: $selectedParagraph,
                    onParagraphSelected: { paragraph in
                        selectedParagraph = paragraph
                        showingParagraphSelector = false
                        startNewSession(with: paragraph)
                    }
                )
            }
            .alert("Feedback", isPresented: .constant(!feedbackMessage.isEmpty)) {
                Button("OK") {
                    feedbackMessage = ""
                }
            } message: {
                Text(feedbackMessage)
            }

        }
        .onReceive(speechManager.$transcribedText) { transcription in
            if currentSession != nil, !transcription.isEmpty {
                updateSession(with: transcription)
            }
        }
        .onAppear {
            // Set header for practice screen
            headerState.showBackButton = false
            headerState.title = "Reading"
            headerState.titleIcon = "book.fill"
            headerState.titleColor = .blue
        }
    }





    private func startNewSession(with paragraph: PracticeParagraph) {
        currentSession = ReadingSession(paragraph: paragraph)
        speechManager.reset()
        ttsManager.stopSpeaking()
        scrollTargetIndex = 0
    }

    private func startPractice() {
        guard var session = currentSession else { return }

        session.startTime = Date()
        currentSession = session
        speechManager.startListening()

        // Provide initial feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let currentWord = session.currentWord {
                ttsManager.speakFeedback("Start by saying: \(currentWord)")
            } else {
                ttsManager.speakFeedback("Begin reading the paragraph aloud")
            }
        }
    }

    private func stopPractice() {
        guard var session = currentSession else { return }

        session.endTime = Date()
        speechManager.stopListening()
        currentSession = session

        // Save session to progress tracking
        saveSessionToProgress(session)

        // Provide final feedback
        let accuracy = session.accuracy
        let feedback: String

        if accuracy >= 0.9 {
            feedback = "Excellent reading! Your pronunciation was very accurate."
        } else if accuracy >= 0.7 {
            feedback = "Good job! You're making great progress with your pronunciation."
        } else if accuracy >= 0.5 {
            feedback = "Keep practicing! Focus on the highlighted words for improvement."
        } else {
            feedback = "Don't worry, pronunciation takes time. Try reading more slowly and clearly."
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ttsManager.speakFeedback(feedback)
        }
    }
    
    private func saveSessionToProgress(_ session: ReadingSession) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let timeSpent = session.endTime?.timeIntervalSince(session.startTime ?? Date()) ?? 0
        
        let readingSession = UserReadingSession(
            sessionId: UUID().uuidString,
            userId: userId,
            articleId: session.paragraph.id,
            articleTitle: session.paragraph.title,
            difficulty: session.paragraph.difficulty.rawValue,
            category: session.paragraph.category.rawValue,
            startTime: session.startTime ?? Date(),
            endTime: session.endTime,
            totalWords: session.totalWords,
            correctWords: session.correctWords,
            accuracy: session.accuracy,
            timeSpent: timeSpent,
            wordsToReview: session.wordsToReview,
            completed: session.isCompleted,
            createdAt: Date()
        )
        
        let progressManager = UserProgressManager()
        progressManager.saveReadingSession(readingSession)
        
        // Update word progress for each word
        for (index, wordAnalysis) in session.wordAnalyses.enumerated() {
            let word = session.paragraph.words[index]
            progressManager.updateWordProgress(
                userId: userId,
                word: word,
                isCorrect: wordAnalysis.isCorrect
            )
        }
    }

    private func updateSession(with transcription: String) {
        guard var session = currentSession else { return }
        let previousWordIndex = session.currentWordIndex
        let wordCompleted = session.analyzeTranscription(transcription)

        // Haptic feedback for correct word
        if wordCompleted {
            DispatchQueue.main.async {
                HapticManager.shared.mediumImpact()
            }
        }

        currentSession = session

        // HYBRID SCROLL: only scroll if currentWordIndex > buffer, and scroll to currentWordIndex - buffer
        let buffer = 5
        let targetIndex: Int
        if session.currentWordIndex > buffer {
            targetIndex = session.currentWordIndex - buffer
        } else {
            targetIndex = 0
        }
        scrollTargetIndex = targetIndex
        if previousWordIndex > session.currentWordIndex { // reset or rewind
            scrollTargetIndex = 0
        }

        if session.currentWord != nil {
            // Current word exists but no specific analysis needed here

        } else if session.isCompleted {
            // All words completed - stop listening automatically
            speechManager.stopListening()

            // Save the completed session to progress tracking
            saveSessionToProgress(session)

            let reviewWords = session.wordsToReview

            if reviewWords.isEmpty {
                feedbackMessage = "Excellent! You've completed the paragraph perfectly! 🎉"
            } else {
                let wordList = reviewWords.joined(separator: ", ")
                feedbackMessage = "Great job! You completed the paragraph. Words to practice: \(wordList) 🎉"
            }
            // Set selectedParagraph for navigation
            if let sessionParagraph = currentSession?.paragraph {
                selectedParagraph = sessionParagraph
            }
        }
    }

    private func handleWordTap(_ word: String) {
        DispatchQueue.main.async {
            HapticManager.shared.mediumImpact()
        }
        ttsManager.speakWord(word)
    }

    private func resetSession() {
        guard let paragraph = currentSession?.paragraph else { return }

        // Stop listening and clear speech recognition
        speechManager.stopListening()
        speechManager.clearTranscription()

        // Stop any ongoing text-to-speech
        ttsManager.stopSpeaking()

        // Clear feedback message
        feedbackMessage = ""

        // Start a completely fresh session
        startNewSession(with: paragraph)

        // Provide feedback about the reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ttsManager.speakFeedback("Starting over. Begin reading the paragraph aloud.")
        }
        scrollTargetIndex = 0
    }

    private func resetToSentenceStart() {
        guard var session = currentSession else {
            return
        }

        // Stop listening temporarily to clear any buffered audio
        let wasListening = speechManager.isListening
        if wasListening {
            speechManager.stopListening()
        }

        session.resetToSentenceStart()
        currentSession = session

        // Clear transcription completely
        speechManager.clearTranscription()

        // Restart listening if it was on before
        if wasListening {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                speechManager.startListening()
            }
        }

        // Provide feedback about the reset
        if let currentWord = session.currentWord {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                ttsManager.speakFeedback("Starting from: \(currentWord)")
            }
        }
        scrollTargetIndex = 0
    }

    private func skipCurrentWord() {
        guard var session = currentSession, !session.isCompleted, session.currentWord != nil else { return }
        session.skipCurrentWord()
        currentSession = session
        // Haptic feedback for skipping
        DispatchQueue.main.async {
            HapticManager.shared.mediumImpact()
        }
        // Optionally, scroll to keep the current word in view
        let buffer = 5
        let targetIndex = session.currentWordIndex > buffer ? session.currentWordIndex - buffer : 0
        scrollTargetIndex = targetIndex
    }
    
    private func skipToEnd() {
        guard var session = currentSession, !session.isCompleted else { return }
        session.skipToEnd()
        currentSession = session
        // Haptic feedback for skipping to end
        DispatchQueue.main.async {
            HapticManager.shared.mediumImpact()
        }
        // Scroll to the end to show completion
        scrollTargetIndex = session.totalWords - 1
    }
    

}


