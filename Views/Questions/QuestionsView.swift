import FirebaseFirestore
import FirebaseAuth
import SwiftUI
import UIKit
import Combine



struct QuestionsView: View {
    let articleId: String
    let practiceSession: ReadingSession? // Optional practice session data
    let sessionId: String? // SessionId from reading session - maintains connection between reading and question sessions
    @StateObject private var viewModel = ArticleViewModel()
    @StateObject private var speechManager = SpeechRecognitionManager()
    @StateObject private var progressManager = UserProgressManager()
    @StateObject private var llmService = LLMEvaluationService()
    @State private var articleContent: String = ""
    @State private var articleTitle: String = ""
    @EnvironmentObject var headerState: HeaderState
    @Environment(\.dismiss) private var dismiss
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
    @State private var showingArticle = false // for showing article in bottom sheet
    
    // Question session tracking
    @State private var sessionStartTime: Date?
    @State private var multipleChoiceCorrect: Int = 0
    @State private var openEndedScores: [Double] = []
    @State private var vocabularyCorrect: Int = 0
    @State private var sessionCompleted: Bool = false
    @State private var showingSubmitButton: Bool = false
    @State private var showingResults: Bool = false
    
    // Section completion timestamps
    @State private var multipleChoiceSectionCompletionTime: Date?
    @State private var openEndedSectionCompletionTime: Date?
    @State private var vocabularySectionCompletionTime: Date?
    
    // Calculated points from database (to be used in quiz complete popup)
    @State private var calculatedTotalPoints: Int = 0
    @State private var calculatedEarnedPoints: Int = 0
    
    // Open-ended question responses storage
    @State private var openEndedResponses: [OpenEndedQuestionResponse] = []
    
    // Multiple choice question responses storage
    @State private var multipleChoiceResponses: [MultipleChoiceQuestionResponse] = []
    
    // Multiple choice section completion tracking
    @State private var multipleChoiceSectionCompleted: Bool = false
    
    // Open-ended section completion tracking
    @State private var openEndedSectionCompleted: Bool = false
    
    // Confirmation modal state
    @State private var showingMultipleChoiceConfirmation: Bool = false
    @State private var showingOpenEndedConfirmation: Bool = false
    
    // Navigation state
    @State private var currentSectionIndex = 0
    @State private var currentQuestionIndex = 0
    @State private var navigateToSessionResults = false
    
    // Computed properties for navigation
    private var sections: [QuestionSection] {
        var sections: [QuestionSection] = []
        
        if !viewModel.multipleChoiceQuestions.isEmpty {
            sections.append(.multipleChoice)
        }
        
        if !viewModel.openEndedQuestions.isEmpty {
            sections.append(.openEnded)
        }
        
        if !vocabularyWords.isEmpty {
            sections.append(.vocabulary)
        }
        
        return sections
    }
    
    private var currentSection: QuestionSection? {
        guard currentSectionIndex < sections.count else { return nil }
        return sections[currentSectionIndex]
    }
    
    private var currentQuestion: Any? {
        guard let section = currentSection else { return nil }
        
        switch section {
        case .multipleChoice:
            guard currentQuestionIndex < viewModel.multipleChoiceQuestions.count else { return nil }
            return viewModel.multipleChoiceQuestions[currentQuestionIndex]
        case .openEnded:
            guard currentQuestionIndex < viewModel.openEndedQuestions.count else { return nil }
            return viewModel.openEndedQuestions[currentQuestionIndex]
        case .vocabulary:
            guard currentQuestionIndex < vocabularyWords.count else { return nil }
            return vocabularyWords[currentQuestionIndex]
        }
    }
    
    private var totalQuestionsInCurrentSection: Int {
        guard let section = currentSection else { return 0 }
        
        switch section {
        case .multipleChoice:
            return viewModel.multipleChoiceQuestions.count
        case .openEnded:
            return viewModel.openEndedQuestions.count
        case .vocabulary:
            return vocabularyWords.count
        }
    }
    
    private var canGoNext: Bool {
        if currentQuestionIndex < totalQuestionsInCurrentSection - 1 {
            return true
        }
        return currentSectionIndex < sections.count - 1
    }
    
    private var canGoPrevious: Bool {
        if currentQuestionIndex > 0 {
            return true
        }
        return currentSectionIndex > 0
    }

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading questions...")
            } else if sections.isEmpty {
                Text("No questions found for this article.")
                    .foregroundColor(.gray)
            } else {
                VStack(spacing: 0) {
                    // Progress indicator
                    ProgressIndicatorView(
                        currentSection: currentSectionIndex,
                        totalSections: sections.count,
                        currentQuestion: currentQuestionIndex + 1,
                        totalQuestions: totalQuestionsInCurrentSection
                    )
                    
                    // Current question content
                    ScrollView {
                        VStack(spacing: 20) {
                            if let section = currentSection, let question = currentQuestion {
                                QuestionContentView(
                                    section: section,
                                    question: question,
                                    questionIndex: currentQuestionIndex,
                                    selectedAnswers: $selectedAnswers,
                                    openEndedAnswers: $openEndedAnswers,
                                    editingAnswers: $editingAnswers,
                                    lockedAnswers: $lockedAnswers,
                                    recordingQuestion: $recordingQuestion,
                                    vocabularyAnswers: $vocabularyAnswers,
                                    vocabularyEditingAnswers: $vocabularyEditingAnswers,
                                    vocabularyLockedAnswers: $vocabularyLockedAnswers,
                                    recordingVocabularyWord: $recordingVocabularyWord,
                                    speechManager: speechManager,
                                    onWordTap: { word in
                                        selectedWord = word
                                        showDictionary(for: word)
                                    },
                                    onMultipleChoiceAnswer: { isCorrect, questionNumber, questionText, studentChoice, correctChoice, studentChoiceText, correctChoiceText in
                                        trackMultipleChoiceAnswer(isCorrect: isCorrect, questionNumber: questionNumber, questionText: questionText, studentChoice: studentChoice, correctChoice: correctChoice, studentChoiceText: studentChoiceText, correctChoiceText: correctChoiceText)
                                    },
                                    onOpenEndedAnswer: { isCorrect in
                                        // We don't need to track here since trackOpenEndedAnswer is called in evaluateWithLLM
                                    },
                                    onVocabularyAnswer: { isCorrect in
                                        trackVocabularyAnswer(isCorrect: isCorrect)
                                    },
                                    articleContent: articleContent,
                                    evaluateWithLLM: { article, questionText, expectedAnswer, studentAnswer, questionNumber in
                                        await evaluateWithLLM(article, questionText, expectedAnswer, studentAnswer, questionNumber)
                                                        },
                                    multipleChoiceSectionCompleted: multipleChoiceSectionCompleted,
                                    openEndedSectionCompleted: openEndedSectionCompleted
                                )
                            }
                        }
                        .padding()
                    }
                    
                    // Navigation controls
                    NavigationControlsView(
                        canGoPrevious: canGoPrevious,
                        canGoNext: canGoNext,
                        onPrevious: goToPrevious,
                        onNext: goToNext,
                        onShowArticle: {
                            showingArticle = true
                        }
                    )
                    
                    // Submit button (show when on last question of last section)
                    if isOnLastQuestion && !sessionCompleted {
                        VStack(spacing: 12) {
                            Button(action: submitAnswers) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Finish Quiz")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .cornerRadius(12)
                            }
                            
                            if allQuestionsCompleted {
                                Text("All questions completed! Review your answers and submit.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("Last one! Review your answers and submit.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingArticle) {
            ArticleView(articleId: articleId, practiceSession: practiceSession)
        }
        .sheet(isPresented: $showingResults) {
            if let earnedPoints = totalPointsEarned, let possiblePoints = totalPossiblePoints {
                QuestionResultsView(
                    totalPointsEarned: earnedPoints,
                    totalPossiblePoints: possiblePoints,
                    multipleChoiceCorrect: multipleChoiceCorrect,
                    multipleChoiceTotal: viewModel.multipleChoiceQuestions.count,
                    openEndedCorrect: openEndedScores.filter { $0 > 0.6 }.count, // Count questions with score > 0.6
                    openEndedTotal: viewModel.openEndedQuestions.count,
                    openEndedScores: openEndedScores,
                    vocabularyCorrect: vocabularyCorrect,
                    vocabularyTotal: vocabularyWords.count,
                    sessionId: questionSessionId ?? "",
                    onDismiss: {
                        showingResults = false
                        navigateToSessionResults = true
                    }
                )
            } else {
                VStack(spacing: 20) {
                    ProgressView("Loading results...")
                        .font(.headline)
                    Text("Please wait while we calculate your score.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
        }
        .background(
            NavigationLink(
                destination: SessionResultsView(sessionId: questionSessionId ?? "", cameFromQuiz: true),
                isActive: $navigateToSessionResults
            ) {
                EmptyView()
            }
        )
        .sheet(isPresented: $showingMultipleChoiceConfirmation) {
            MultipleChoiceConfirmationView(
                onConfirm: {
                    completeMultipleChoiceSection()
                    showingMultipleChoiceConfirmation = false
                    // Move to next section
                    currentSectionIndex += 1
                    currentQuestionIndex = 0
                },
                onCancel: {
                    showingMultipleChoiceConfirmation = false
                },
                answeredQuestions: selectedAnswers.count,
                totalQuestions: viewModel.multipleChoiceQuestions.count
            )
        }
        .sheet(isPresented: $showingOpenEndedConfirmation) {
            OpenEndedConfirmationView(
                onConfirm: {
                    completeOpenEndedSection()
                    showingOpenEndedConfirmation = false
                    // Move to next section
                    currentSectionIndex += 1
                    currentQuestionIndex = 0
                },
                onCancel: {
                    showingOpenEndedConfirmation = false
                },
                answeredQuestions: openEndedAnswers.count,
                totalQuestions: viewModel.openEndedQuestions.count
            )
        }
        .onAppear {
            // Set up header
            headerState.showBackButton = true
            headerState.backButtonAction = {
                dismiss()
            }
            updateHeaderTitle()
            
            viewModel.fetchQuestions(for: articleId)
            // Initialize vocabularyWords to always have 5 words
            if let session = practiceSession, !session.incorrectImportantWordsSet.isEmpty {
                // Start with incorrect words from practice session
                let incorrectWords = Array(session.incorrectImportantWordsSet)
                    .sorted()
                    .map { word in
                        // Remove punctuation and capitalize first letter
                        let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
                        return cleanWord.prefix(1).uppercased() + cleanWord.dropFirst().lowercased()
                    }
                
                // If we have fewer than 5 incorrect words, add important words from article
                if incorrectWords.count < 5 {
                    let additionalWords = getImportantWordsFromArticle()
                        .filter { word in
                            // Filter out words that are already in incorrect words
                            !incorrectWords.contains { incorrectWord in
                                incorrectWord.lowercased() == word.lowercased()
                            }
                        }
                        .prefix(5 - incorrectWords.count)
                    
                    vocabularyWords = incorrectWords + Array(additionalWords)
                } else {
                    // If we have 5 or more incorrect words, take the first 5
                    vocabularyWords = Array(incorrectWords.prefix(5))
                }
            } else {
                vocabularyWords = getImportantWordsFromArticle()
            }
            
            // Log warning if old sessionId is passed (for debugging)
            if let oldSessionId = sessionId {
                print("⚠️ WARNING: sessionId passed to QuestionsView: \(oldSessionId)")
                print("📋 This sessionId should come from a fresh reading session")
                print("🔗 It will be used to link this question session to the reading session")
            } else {
                print("ℹ️ No sessionId passed to QuestionsView - will generate new one")
            }
            
            // Start question session tracking
            startQuestionSession()
            
            // Fetch article content for LLM evaluation
            fetchArticleContent()
            
            // Add a slight delay to show loading spinner
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isLoading = false
            }
        }
        .onChange(of: currentSection) { _, section in
            updateHeaderTitle()
        }
        .onDisappear {
            // Complete multiple choice section if not already completed
            if !multipleChoiceSectionCompleted && !viewModel.multipleChoiceQuestions.isEmpty {
                completeMultipleChoiceSection()
            }
            
            // Complete open-ended section if not already completed
            if !openEndedSectionCompleted && !viewModel.openEndedQuestions.isEmpty {
                completeOpenEndedSection()
            }
            
            // Save question sessions if not already completed
            if !sessionCompleted {
                saveQuestionSessions()
            }
            
            // Restore practice view header when leaving questions view
            headerState.showBackButton = false
            headerState.title = "Reading"
            headerState.titleIcon = "book.fill"
            headerState.titleColor = .blue
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
    
    // Navigation functions
    private func goToNext() {
        if currentQuestionIndex < totalQuestionsInCurrentSection - 1 {
            currentQuestionIndex += 1
        } else if currentSectionIndex < sections.count - 1 {
            // Check if we're completing the multiple choice section
            if currentSection == .multipleChoice && !multipleChoiceSectionCompleted {
                showingMultipleChoiceConfirmation = true
                return
            }
            
            // Check if we're completing the open-ended section
            if currentSection == .openEnded && !openEndedSectionCompleted {
                showingOpenEndedConfirmation = true
                return
            }
            
            currentSectionIndex += 1
            currentQuestionIndex = 0
        }
    }
    
    private func goToPrevious() {
        if currentQuestionIndex > 0 {
            currentQuestionIndex -= 1
        } else if currentSectionIndex > 0 {
            currentSectionIndex -= 1
            currentQuestionIndex = totalQuestionsInCurrentSection - 1
            
            // If we're going back to multiple choice section and it's completed, ensure it stays completed
            if currentSection == .multipleChoice && multipleChoiceSectionCompleted {
                // Section is already completed, no additional action needed
            }
            
            // If we're going back to open-ended section and it's completed, ensure it stays completed
            if currentSection == .openEnded && openEndedSectionCompleted {
                // Section is already completed, no additional action needed
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
    
    // MARK: - Question Session Tracking
    
    @State private var questionSessionId: String?
    
    private func startQuestionSession() {
        print("Starting fresh question session - resetting all state")
        
        // Reset all session state to ensure complete freshness
        sessionStartTime = Date()
        multipleChoiceCorrect = 0
        openEndedScores.removeAll()
        multipleChoiceResponses.removeAll()
        openEndedResponses.removeAll()
        vocabularyCorrect = 0
        sessionCompleted = false
        multipleChoiceSectionCompleted = false
        openEndedSectionCompleted = false
        multipleChoiceSectionCompletionTime = nil
        openEndedSectionCompletionTime = nil
        vocabularySectionCompletionTime = nil
        
        // Clear all answer storage to prevent old answers from persisting
        selectedAnswers.removeAll()
        openEndedAnswers.removeAll()
        editingAnswers.removeAll()
        lockedAnswers.removeAll()
        vocabularyAnswers.removeAll()
        vocabularyEditingAnswers.removeAll()
        vocabularyLockedAnswers.removeAll()
        
        // Reset navigation state
        currentSectionIndex = 0
        currentQuestionIndex = 0
        
        // Clear any previous session ID
        questionSessionId = nil
        
        print("Session state reset complete. Starting fresh session at: \(sessionStartTime?.formatted() ?? "unknown time")")
        
        // Create the question session document at the start
        createQuestionSessionDocument()
    }
    
    private func createQuestionSessionDocument() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Use the passed sessionId from the reading session to maintain the connection
        // This ensures question sessions are properly linked to their reading sessions
        let sessionId = self.sessionId ?? UUID().uuidString
        questionSessionId = sessionId
        
        print("Creating question session linked to reading session: \(sessionId) for article: \(articleId)")
        
        // Create initial session document with basic info
        let initialSessionData: [String: Any] = [
            "sessionId": sessionId,
            "userId": userId,
            "articleId": articleId,
            "totalTimeSpent": 0,
            "completed": false,
            "totalPoints": 0,
            "earnedPoints": 0,
            "createdAt": Timestamp(date: Date()),
            "accuracy": 0.0
        ]
        
        let db = Firestore.firestore()
        db.collection("question_sessions").document(sessionId).setData(initialSessionData) { error in
            if let error = error {
                print("Error creating question session: \(error.localizedDescription)")
            } else {
                print("Successfully created question session linked to reading session: \(sessionId)")
            }
        }
    }
    
    private func trackMultipleChoiceAnswer(isCorrect: Bool, questionNumber: Int, questionText: String, studentChoice: String, correctChoice: String, studentChoiceText: String, correctChoiceText: String) {
        // Only track if multiple choice section is not completed
        guard !multipleChoiceSectionCompleted else { return }
        
        if isCorrect {
            multipleChoiceCorrect += 1
        }
        
        // Create detailed response with new array format
        let response = MultipleChoiceQuestionResponse(
            questionNumber: questionNumber,
            questionText: questionText,
            studentAnswer: [studentChoice, studentChoiceText], // [choice_identifier, choice_text]
            correctAnswer: [correctChoice, correctChoiceText], // [choice_identifier, choice_text]
            isCorrect: isCorrect,
            timestamp: Date()
        )
        
        // Add to responses array (but don't save to Firestore yet)
        multipleChoiceResponses.append(response)
    }
    
    private func trackOpenEndedAnswer(score: Double) {
        openEndedScores.append(score)
    }
    
    private func trackVocabularyAnswer(isCorrect: Bool) {
        if isCorrect {
            vocabularyCorrect += 1
        }
    }
    
    // Complete multiple choice section and save responses to Firestore
    private func completeMultipleChoiceSection() {
        guard !multipleChoiceSectionCompleted else { return }
        
        multipleChoiceSectionCompleted = true
        multipleChoiceSectionCompletionTime = Date()
        
        // Save all multiple choice responses to Firestore
        guard let userId = Auth.auth().currentUser?.uid,
              let sessionId = questionSessionId else { return }
        
        saveMultipleChoiceResponsesCollection(userId: userId, questionSessionId: sessionId)
        
        print("Multiple choice section completed at \(multipleChoiceSectionCompletionTime?.formatted() ?? "unknown time"). Saved \(multipleChoiceResponses.count) responses to Firestore.")
    }
    
    // Complete open-ended section (no Firestore upload needed)
    private func completeOpenEndedSection() {
        guard !openEndedSectionCompleted else { return }
        
        // Auto-lock all unlocked open-ended answers to trigger evaluation
        print("Auto-locking open-ended answers for section completion...")
        var autoLockedCount = 0
        var evaluatedCount = 0
        
        for question in viewModel.openEndedQuestions {
            let questionText = question.questionText
            if !lockedAnswers.contains(questionText) {
                // Lock the answer if it's not already locked
                lockedAnswers.insert(questionText)
                autoLockedCount += 1
                
                // Get the current answer (either from editing or final answers)
                let currentAnswer = openEndedAnswers[questionText] ?? editingAnswers[questionText] ?? ""
                
                // Only evaluate if there's an actual answer
                if !currentAnswer.isEmpty {
                    // Ensure the answer is saved to openEndedAnswers if it was only in editingAnswers
                    if openEndedAnswers[questionText] == nil && editingAnswers[questionText] != nil {
                        openEndedAnswers[questionText] = editingAnswers[questionText]
                        print("Moved answer from editing to final for: \(questionText)")
                    }
                    
                    // Evaluate the answer using LLM
                    evaluatedCount += 1
                    Task {
                        let isCorrect = await evaluateWithLLM(
                            articleContent.isEmpty ? "No article content available" : articleContent,
                            questionText,
                            question.answer,
                            currentAnswer,
                            viewModel.openEndedQuestions.firstIndex(where: { $0.questionText == questionText }) ?? 0
                        )
                        
                        await MainActor.run {
                            // Track the score for session calculation
                            trackOpenEndedAnswer(score: isCorrect ? 1.0 : 0.0)
                            
                            // Debug logging
                            print("Auto-evaluated open-ended question: \(questionText)")
                            print("Answer: \(currentAnswer)")
                            print("Is Correct: \(isCorrect)")
                        }
                    }
                } else {
                    print("No answer found for question: \(questionText) - skipping evaluation")
                }
            } else {
                print("Question already locked: \(questionText)")
            }
        }
        
        print("Auto-locked \(autoLockedCount) answers, evaluated \(evaluatedCount) answers")
        
        openEndedSectionCompleted = true
        openEndedSectionCompletionTime = Date()
        
        print("Open-ended section completed at \(openEndedSectionCompletionTime?.formatted() ?? "unknown time") with auto-locked answers. Total questions: \(viewModel.openEndedQuestions.count)")
    }
    
    private func saveQuestionSessions() {
        guard let userId = Auth.auth().currentUser?.uid,
              let startTime = sessionStartTime,
              let sessionId = questionSessionId else { return }
        
        let timeSpent = Date().timeIntervalSince(startTime)
        
        // Prepare data for each question type
        let multipleChoiceData: (totalQuestions: Int, correctAnswers: Int, timeSpent: TimeInterval)? = 
            !viewModel.multipleChoiceQuestions.isEmpty ? (
                totalQuestions: viewModel.multipleChoiceQuestions.count,
                correctAnswers: multipleChoiceCorrect,
                timeSpent: multipleChoiceSectionCompletionTime?.timeIntervalSince(sessionStartTime ?? Date()) ?? 0
            ) : nil
        
        let openEndedData: (totalQuestions: Int, correctAnswers: Int, timeSpent: TimeInterval, scores: [Double])? = 
            !viewModel.openEndedQuestions.isEmpty ? (
                totalQuestions: viewModel.openEndedQuestions.count,
                correctAnswers: openEndedScores.filter { $0 > 0.6 }.count, // Count of questions with score > 0.6
                timeSpent: openEndedSectionCompletionTime?.timeIntervalSince(multipleChoiceSectionCompletionTime ?? Date()) ?? 0,
                scores: openEndedScores
            ) : nil
        
        let vocabularyData: (totalQuestions: Int, correctAnswers: Int, timeSpent: TimeInterval)? = 
            !vocabularyWords.isEmpty ? (
                totalQuestions: vocabularyWords.count,
                correctAnswers: vocabularyCorrect,
                timeSpent: vocabularySectionCompletionTime?.timeIntervalSince(openEndedSectionCompletionTime ?? Date()) ?? 0
            ) : nil
        
        // Update the existing question session with final data
        let (totalPoints, earnedPoints) = progressManager.updateQuestionSession(
            sessionId: questionSessionId ?? "",
            userId: userId,
            articleId: articleId,
            articleTitle: articleTitle,
            multipleChoiceData: multipleChoiceData,
            openEndedData: openEndedData,
            vocabularyData: vocabularyData,
            completed: true
        )
        
        // Store the calculated points for use in the quiz complete popup
        calculatedTotalPoints = totalPoints
        calculatedEarnedPoints = earnedPoints
        
        // Save open-ended responses as a nested collection within the question session
        saveOpenEndedResponsesCollection(userId: userId, questionSessionId: questionSessionId ?? "")
        
        // Save multiple choice responses as a nested collection within the question session
        saveMultipleChoiceResponsesCollection(userId: userId, questionSessionId: questionSessionId ?? "")
        
        sessionCompleted = true
    }
    
    private func submitAnswers() {

        vocabularySectionCompletionTime = Date()

        // Complete multiple choice section if not already completed
        if !multipleChoiceSectionCompleted && !viewModel.multipleChoiceQuestions.isEmpty {
            completeMultipleChoiceSection()
        }
        
        // Complete open-ended section if not already completed
        if !openEndedSectionCompleted && !viewModel.openEndedQuestions.isEmpty {
            completeOpenEndedSection()
        }
        
        // Save all question sessions
        saveQuestionSessions()
        
        // Show results
        showingResults = true
    }
    
    private func getTotalQuestions() -> Int {
        return viewModel.multipleChoiceQuestions.count + 
               viewModel.openEndedQuestions.count + 
               vocabularyWords.count
    }
    
    // Fetch article content for LLM evaluation
    private func fetchArticleContent() {
        let db = Firestore.firestore()
        db.collection("articles").document(articleId).getDocument { snapshot, error in
            if let data = snapshot?.data() {
                self.articleContent = data["content"] as? String ?? ""
                self.articleTitle = data["title"] as? String ?? ""
            }
        }
    }
    
    // Save individual open-ended question response to Firestore
    private func saveOpenEndedResponse(_ response: OpenEndedQuestionResponse) {
        guard let userId = Auth.auth().currentUser?.uid,
              let sessionId = questionSessionId else { return }
        
        let db = Firestore.firestore()
        
        do {
            let data = try JSONEncoder().encode(response)
            var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            // Convert timestamp to Firestore Timestamp
            dict["timestamp"] = Timestamp(date: response.timestamp)
            
            // Add required fields for Firestore rules
            dict["userId"] = userId
            dict["articleId"] = articleId
            dict["sessionId"] = sessionId
            
            // Create a unique document ID for this response (unused, but kept for reference)
            _ = "\(userId)_\(articleId)_\(response.questionNumber)"
            
            // Save ONLY to the nested structure within the question session
            let nestedDocRef = db.collection("question_sessions")
                .document(sessionId)
                .collection("open_ended_responses")
                .document("question_\(response.questionNumber)")
            
            nestedDocRef.setData(dict) { error in
                if let error = error {
                    print("Error saving nested open-ended response: \(error.localizedDescription)")
                } else {
                    print("Successfully saved nested open-ended response for question \(response.questionNumber)")
                }
            }
        } catch {
            print("Error encoding open-ended response: \(error.localizedDescription)")
        }
    }
    
    // Save open-ended responses as a nested collection within the question session
    private func saveOpenEndedResponsesCollection(userId: String, questionSessionId: String) {
        guard !openEndedResponses.isEmpty else { return }
        
        let db = Firestore.firestore()
        
        // Create a batch write for all responses
        let batch = db.batch()
        
        for response in openEndedResponses {
            do {
                let data = try JSONEncoder().encode(response)
                var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                
                // Convert timestamp to Firestore Timestamp
                dict["timestamp"] = Timestamp(date: response.timestamp)
                dict["userId"] = userId
                dict["articleId"] = articleId
                
                // Save to the open_ended_responses subcollection within the question session
                let docRef = db.collection("question_sessions")
                    .document(questionSessionId)
                    .collection("open_ended_responses")
                    .document("question_\(response.questionNumber)")
                
                batch.setData(dict, forDocument: docRef)
            } catch {
                print("Error encoding response for question \(response.questionNumber): \(error.localizedDescription)")
            }
        }
        
        // Commit the batch
        batch.commit { error in
            if let error = error {
                print("Error saving open-ended responses: \(error.localizedDescription)")
            } else {
                print("Successfully saved \(openEndedResponses.count) open-ended responses")
            }
        }
    }
    
    // Save individual multiple choice question response to Firestore
    private func saveMultipleChoiceResponse(_ response: MultipleChoiceQuestionResponse) {
        guard let userId = Auth.auth().currentUser?.uid,
              let sessionId = questionSessionId else { return }
        
        let db = Firestore.firestore()
        
        do {
            let data = try JSONEncoder().encode(response)
            var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            // Convert timestamp to Firestore Timestamp
            dict["timestamp"] = Timestamp(date: response.timestamp)
            
            // Add required fields for Firestore rules
            dict["userId"] = userId
            dict["articleId"] = articleId
            dict["sessionId"] = sessionId
            
            // Save to the multiple_choice_responses subcollection within the question session
            let nestedDocRef = db.collection("question_sessions")
                .document(sessionId)
                .collection("multiple_choice_responses")
                .document("question_\(response.questionNumber)")
            
            nestedDocRef.setData(dict) { error in
                if let error = error {
                    print("Error saving nested multiple choice response: \(error.localizedDescription)")
                } else {
                    print("Successfully saved nested multiple choice response for question \(response.questionNumber)")
                }
            }
        } catch {
            print("Error encoding multiple choice response: \(error.localizedDescription)")
        }
    }
    
    // Save multiple choice responses as a nested collection within the question session
    private func saveMultipleChoiceResponsesCollection(userId: String, questionSessionId: String) {
        guard !multipleChoiceResponses.isEmpty else { return }
        
        let db = Firestore.firestore()
        
        // Create a batch write for all responses
        let batch = db.batch()
        
        for response in multipleChoiceResponses {
            do {
                let data = try JSONEncoder().encode(response)
                var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                
                // Convert timestamp to Firestore Timestamp
                dict["timestamp"] = Timestamp(date: response.timestamp)
                dict["userId"] = userId
                dict["articleId"] = articleId
                
                // Save to the multiple_choice_responses subcollection within the question session
                let docRef = db.collection("question_sessions")
                    .document(questionSessionId)
                    .collection("multiple_choice_responses")
                    .document("question_\(response.questionNumber)")
                
                batch.setData(dict, forDocument: docRef)
            } catch {
                print("Error encoding response for question \(response.questionNumber): \(error.localizedDescription)")
            }
        }
        
        // Commit the batch
        batch.commit { error in
            if let error = error {
                print("Error saving multiple choice responses: \(error.localizedDescription)")
            } else {
                print("Successfully saved \(multipleChoiceResponses.count) multiple choice responses")
            }
        }
    }
    
    // Async function to evaluate with LLM
    private func evaluateWithLLM(
        _ article: String,
        _ questionText: String,
        _ expectedAnswer: String,
        _ studentAnswer: String,
        _ questionNumber: Int
    ) async -> Bool {
        let evaluation = await llmService.evaluateOpenEndedAnswer(
            article: article,
            questionText: questionText,
            expectedAnswer: expectedAnswer,
            studentAnswer: studentAnswer
        )
        
        // Store the detailed response if evaluation is available
        if let evaluation = evaluation {
            // Determine isCorrect based on score threshold (0.6)
            let isCorrect = evaluation.score > 0.6
            
            let response = OpenEndedQuestionResponse(
                questionNumber: questionNumber,
                questionText: questionText,
                studentAnswer: studentAnswer,
                llmFeedback: evaluation.feedback,
                                        llmReason: evaluation.reasoning,
                score: evaluation.score,
                isCorrect: isCorrect,
                timestamp: Date()
            )
            
            // Add to responses array
            openEndedResponses.append(response)
            
            // Track the score for session calculation
            trackOpenEndedAnswer(score: evaluation.score)
            
            // Save individual response to Firestore
            saveOpenEndedResponse(response)
        }
        
        // Return the calculated isCorrect value based on score threshold
        if let evaluation = evaluation {
            return evaluation.score > 0.6
        }
        return false
    }
    
    // Check if all questions are completed
    private var allQuestionsCompleted: Bool {
        let multipleChoiceCompleted = viewModel.multipleChoiceQuestions.allSatisfy { question in
            selectedAnswers[question.questionText] != nil
        }
        
        let openEndedCompleted = viewModel.openEndedQuestions.allSatisfy { question in
            !(openEndedAnswers[question.questionText] ?? "").isEmpty
        }
        
        let vocabularyCompleted = vocabularyWords.allSatisfy { word in
            !(vocabularyAnswers[word] ?? "").isEmpty
        }
        
        return multipleChoiceCompleted && openEndedCompleted && vocabularyCompleted
    }
    
    // Check if user is on the last question of the last section
    private var isOnLastQuestion: Bool {
        // Check if we're on the last section
        guard currentSectionIndex == sections.count - 1 else { return false }
        
        // Check if we're on the last question of that section
        return currentQuestionIndex == totalQuestionsInCurrentSection - 1
    }
    
    // Calculate total points earned
    private var totalPointsEarned: Int? {
        // Use calculated points from database if available (after session completion)
        if sessionCompleted && calculatedEarnedPoints > 0 {
            return calculatedEarnedPoints
        }
        // Return nil if data is not available yet
        return nil
    }
    
    // Calculate total possible points
    private var totalPossiblePoints: Int? {
        // Use calculated points from database if available (after session completion)
        if sessionCompleted && calculatedTotalPoints > 0 {
            return calculatedTotalPoints
        }
        // Return nil if data is not available yet
        return nil
    }
    
    // Update header title based on current section
    private func updateHeaderTitle() {
        if let section = currentSection {
            headerState.title = section.rawValue
            headerState.titleIcon = section.icon
            headerState.titleColor = section.color
        } else {
            headerState.title = ""
            headerState.titleIcon = ""
        }
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
            .map { word in
                // Remove punctuation and capitalize first letter
                let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
                return cleanWord.prefix(1).uppercased() + cleanWord.dropFirst().lowercased()
            }
        
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

// Helper function to get the correct answer text from the choice reference
private func getCorrectAnswerText(for question: MultipleChoiceQuestion) -> String {
    // The answer field contains "choice_a", "choice_b", etc.
    // We need to map this to the actual choice text
    let choiceMapping = [
        "choice_a": 0,
        "choice_b": 1,
        "choice_c": 2,
        "choice_d": 3
    ]
    
    guard let choiceIndex = choiceMapping[question.answer],
          choiceIndex < question.choices.count else {
        print("Invalid choice reference: \(question.answer)")
        return ""
    }
    
    return question.choices[choiceIndex]
}

// MARK: - Results View

// MARK: - Supporting Types and Views




















