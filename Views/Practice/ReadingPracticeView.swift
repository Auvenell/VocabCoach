import SwiftUI
import FirebaseAuth

struct ReadingPracticeView: View {
    @StateObject private var speechManager = SpeechRecognitionManager()
    @StateObject private var ttsManager = TextToSpeechManager()
    @StateObject private var dataManager = ParagraphDataManager()
    @StateObject private var progressManager = UserProgressManager()
    @EnvironmentObject var headerState: HeaderState

    @State private var currentSession: ReadingSession?
    @State private var selectedParagraph: PracticeParagraph?
    @State private var showingResults = false
    @State private var feedbackMessage = ""
    @State private var scrollTargetIndex: Int? = nil
    @State private var showQuestions = false
    @State private var sessionSaved = false


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
                                pausePractice()
                            } else if let session = currentSession, session.isPaused {
                                resumePractice()
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
                    ParagraphSelectorView(
                        dataManager: dataManager,
                        selectedParagraph: $selectedParagraph,
                        onParagraphSelected: { paragraph in
                            selectedParagraph = paragraph
                            startNewSession(with: paragraph)
                        }
                    )
                    .navigationBarHidden(true)
                }
            }
            .padding()
            .navigationDestination(isPresented: $showQuestions) {
                QuestionsView(
                    articleId: selectedParagraph?.id ?? "",
                    practiceSession: currentSession,
                    sessionId: currentSession?.sessionId
                )
                .environmentObject(headerState)
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
            if let session = currentSession, !session.isPaused, !transcription.isEmpty {
                updateSession(with: transcription)
            }
        }
        .onAppear {
            // Set header for practice screen
            headerState.showBackButton = false
            headerState.title = "Reading"
            headerState.titleIcon = "book.fill"
            headerState.titleColor = .blue
            
            // Reset session state to ensure fresh sessions are created
            // This prevents reusing old completed sessions when navigating back
            print("🔄 ReadingPracticeView appeared - resetting all session state")
            
            // Clear all session-related state
            currentSession = nil
            selectedParagraph = nil
            sessionSaved = false
            showQuestions = false
            
            // Reset speech and TTS managers to ensure clean state
            speechManager.reset()
            ttsManager.stopSpeaking()
            
            print("✅ Session state reset complete - ready for fresh session creation")
            
            // Load user progress when view appears
            if let userId = Auth.auth().currentUser?.uid {
                progressManager.loadUserProgress(userId: userId)
            }
        }
    }





    private func startNewSession(with paragraph: PracticeParagraph) {
        print("🚀 Starting completely fresh reading session for paragraph: \(paragraph.title)")
        
        // Always create a completely fresh session with a new UUID
        // This ensures that even if the same paragraph is selected, we get a new session
        currentSession = ReadingSession(paragraph: paragraph)
        sessionSaved = false
        speechManager.reset()
        ttsManager.stopSpeaking()
        scrollTargetIndex = 0
        
        // Debug logging to confirm new session creation
        print("✅ Created new reading session with ID: \(currentSession?.sessionId ?? "unknown")")
        print("📝 Session details - Total words: \(currentSession?.totalWords ?? 0)")
        
        // Verify the session is completely fresh
        guard let session = currentSession else {
            print("❌ Failed to create new session")
            return
        }
        
        print("🆕 Fresh session confirmed - SessionId: \(session.sessionId)")
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

    // Pause the current reading session - session is NOT saved to Firestore
    // Only completed sessions (all words read) get saved automatically
    private func pausePractice() {
        guard var session = currentSession else { return }

        // Mark session as paused
        session.isPaused = true
        speechManager.stopListening()
        currentSession = session

        // Provide feedback about pausing
        ttsManager.speakFeedback("Session paused. Tap resume to continue.")
    }

    // Resume a paused reading session from exactly where it was left off
    private func resumePractice() {
        guard var session = currentSession else { return }

        // Resume from where we left off
        session.isPaused = false
        speechManager.startListening()
        currentSession = session

        // Provide feedback about resuming
        if let currentWord = session.currentWord {
            ttsManager.speakFeedback("Resuming from: \(currentWord)")
        }
    }


    
    // Save completed reading session to Firestore progress tracking
    // This is ONLY called automatically when user completes reading all words
    private func saveSessionToProgress(_ session: ReadingSession) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Prevent double-saving
        guard !sessionSaved else { return }
        sessionSaved = true
        
        // Ensure progress is loaded before saving session
        if progressManager.currentProgress == nil {
            progressManager.loadUserProgress(userId: userId)
            // Wait a bit for the async load to complete, then save
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.saveSessionToProgress(session)
            }
            return
        }
        
        let timeSpent = session.endTime?.timeIntervalSince(session.startTime ?? Date()) ?? 0
        
        // Debug logging
        print("Saving session - Total words: \(session.totalWords), Correct words: \(session.correctWords)")
        print("Current progress - Total words read: \(progressManager.currentProgress?.totalWordsRead ?? 0), Total words correct: \(progressManager.currentProgress?.totalWordsCorrect ?? 0)")
        
        let readingSession = UserReadingSession(
            sessionId: session.sessionId, // Use the sessionId from ReadingSession
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
        
        // Use the injected progressManager instance instead of creating a new one
        progressManager.saveReadingSession(readingSession)
        
        // Update word progress for each word
        /* for (index, wordAnalysis) in session.wordAnalyses.enumerated() {
            let word = session.paragraph.words[index]
            progressManager.updateWordProgress(
                userId: userId,
                word: word,
                isCorrect: wordAnalysis.isCorrect
            )
        } */
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

            // Set end time before saving
            session.endTime = Date()
            currentSession = session
            
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
        let wasPaused = session.isPaused
        if wasListening {
            speechManager.stopListening()
        }

        session.resetToSentenceStart()
        currentSession = session

        // Clear transcription completely
        speechManager.clearTranscription()

        // Restart listening if it was on before (but not if it was paused)
        if wasListening && !wasPaused {
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


