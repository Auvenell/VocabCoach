import FirebaseFirestore
import FirebaseAuth
import SwiftUI
import UIKit

// MARK: - Open-Ended Question Response Data Structure

struct OpenEndedQuestionResponse: Codable {
    let questionNumber: Int
    let questionText: String
    let studentAnswer: String
    let llmFeedback: String
    let llmReason: String
    let score: Double
    let isCorrect: Bool
    let timestamp: Date
}

struct QuestionsView: View {
    let articleId: String
    let practiceSession: ReadingSession? // Optional practice session data
    @StateObject private var viewModel = ArticleViewModel()
    @StateObject private var speechManager = SpeechRecognitionManager()
    @StateObject private var progressManager = UserProgressManager()
    @StateObject private var llmService = LLMEvaluationService()
    @State private var articleContent: String = ""
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
    
    // Open-ended question responses storage
    @State private var openEndedResponses: [OpenEndedQuestionResponse] = []
    
    // Navigation state
    @State private var currentSectionIndex = 0
    @State private var currentQuestionIndex = 0
    
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
                                    onMultipleChoiceAnswer: { isCorrect in
                                        trackMultipleChoiceAnswer(isCorrect: isCorrect)
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
                                    evaluateOpenEndedAnswer: { userAnswer, expectedAnswer in
                                        evaluateOpenEndedAnswer(userAnswer, expectedAnswer)
                                    }
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
                    
                    // Submit button (show when all questions completed)
                    if allQuestionsCompleted && !sessionCompleted {
                        VStack(spacing: 12) {
                            Button(action: submitAnswers) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Submit Answers")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .cornerRadius(12)
                            }
                            
                            Text("All questions completed! Review your answers and submit.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
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
            QuestionResultsView(
                totalPointsEarned: totalPointsEarned,
                totalPossiblePoints: totalPossiblePoints,
                multipleChoiceCorrect: multipleChoiceCorrect,
                multipleChoiceTotal: viewModel.multipleChoiceQuestions.count,
                openEndedCorrect: openEndedScores.filter { $0 > 0.6 }.count, // Count questions with score > 0.6
                openEndedTotal: viewModel.openEndedQuestions.count,
                vocabularyCorrect: vocabularyCorrect,
                vocabularyTotal: vocabularyWords.count,
                onDismiss: {
                    showingResults = false
                    dismiss()
                }
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
            // Initialize vocabularyWords from practice session or article
            if let session = practiceSession, !session.incorrectImportantWordsSet.isEmpty {
                vocabularyWords = Array(session.incorrectImportantWordsSet)
                    .sorted()
                    .map { word in
                        // Remove punctuation and capitalize first letter
                        let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
                        return cleanWord.prefix(1).uppercased() + cleanWord.dropFirst().lowercased()
                    }
            } else {
                vocabularyWords = getImportantWordsFromArticle()
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
    
    // MARK: - Question Session Tracking
    
    @State private var questionSessionId: String?
    
    private func startQuestionSession() {
        sessionStartTime = Date()
        multipleChoiceCorrect = 0
        openEndedScores.removeAll()
        vocabularyCorrect = 0
        sessionCompleted = false
        
        // Create the question session document at the start
        createQuestionSessionDocument()
    }
    
    private func createQuestionSessionDocument() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let sessionId = UUID().uuidString
        questionSessionId = sessionId
        
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
                print("Successfully created question session: \(sessionId)")
            }
        }
    }
    
    private func trackMultipleChoiceAnswer(isCorrect: Bool) {
        if isCorrect {
            multipleChoiceCorrect += 1
        }
    }
    
    private func trackOpenEndedAnswer(score: Double) {
        openEndedScores.append(score)
    }
    
    private func trackVocabularyAnswer(isCorrect: Bool) {
        if isCorrect {
            vocabularyCorrect += 1
        }
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
                timeSpent: timeSpent * Double(viewModel.multipleChoiceQuestions.count) / Double(getTotalQuestions())
            ) : nil
        
        let openEndedData: (totalQuestions: Int, correctAnswers: Int, timeSpent: TimeInterval, scores: [Double])? = 
            !viewModel.openEndedQuestions.isEmpty ? (
                totalQuestions: viewModel.openEndedQuestions.count,
                correctAnswers: openEndedScores.filter { $0 > 0.6 }.count, // Count of questions with score > 0.6
                timeSpent: timeSpent * Double(viewModel.openEndedQuestions.count) / Double(getTotalQuestions()),
                scores: openEndedScores
            ) : nil
        
        let vocabularyData: (totalQuestions: Int, correctAnswers: Int, timeSpent: TimeInterval)? = 
            !vocabularyWords.isEmpty ? (
                totalQuestions: vocabularyWords.count,
                correctAnswers: vocabularyCorrect,
                timeSpent: timeSpent * Double(vocabularyWords.count) / Double(getTotalQuestions())
            ) : nil
        
        // Update the existing question session with final data
        progressManager.updateQuestionSession(
            sessionId: sessionId,
            userId: userId,
            articleId: articleId,
            multipleChoiceData: multipleChoiceData,
            openEndedData: openEndedData,
            vocabularyData: vocabularyData,
            completed: true
        )
        
        // Save open-ended responses as a nested collection within the question session
        saveOpenEndedResponsesCollection(userId: userId, questionSessionId: sessionId)
        
        sessionCompleted = true
    }
    
    private func submitAnswers() {
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
    
    // Evaluate open-ended answer using LLM
    private func evaluateOpenEndedAnswer(_ userAnswer: String, _ expectedAnswer: String) -> Bool {
        // For now, return a simple evaluation
        // In the future, this will call the LLM service
        let userAnswerLower = userAnswer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let expectedAnswerLower = expectedAnswer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Simple keyword matching for now
        let userWords = Set(userAnswerLower.components(separatedBy: .whitespaces))
        let expectedWords = Set(expectedAnswerLower.components(separatedBy: .whitespaces))
        
        let commonWords = userWords.intersection(expectedWords)
        let similarity = Double(commonWords.count) / Double(max(expectedWords.count, 1))
        
        return similarity >= 0.3 // 30% keyword overlap
    }
    
    // Fetch article content for LLM evaluation
    private func fetchArticleContent() {
        let db = Firestore.firestore()
        db.collection("articles").document(articleId).getDocument { snapshot, error in
            if let data = snapshot?.data() {
                self.articleContent = data["content"] as? String ?? ""
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
            
            // Create a unique document ID for this response
            let documentId = "\(userId)_\(articleId)_\(response.questionNumber)"
            
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
    
    // Calculate total points earned
    private var totalPointsEarned: Int {
        let multipleChoicePoints = multipleChoiceCorrect * 8
        let openEndedPoints = Int(openEndedScores.reduce(0, +) * 10) // Sum of scores * 10 points per question
        let vocabularyPoints = vocabularyCorrect * 2
        return multipleChoicePoints + openEndedPoints + vocabularyPoints
    }
    
    // Calculate total possible points
    private var totalPossiblePoints: Int {
        let multipleChoiceTotal = viewModel.multipleChoiceQuestions.count * 8
        let openEndedTotal = viewModel.openEndedQuestions.count * 10
        let vocabularyTotal = vocabularyWords.count * 2
        return multipleChoiceTotal + openEndedTotal + vocabularyTotal
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

struct QuestionResultsView: View {
    let totalPointsEarned: Int
    let totalPossiblePoints: Int
    let multipleChoiceCorrect: Int
    let multipleChoiceTotal: Int
    let openEndedCorrect: Int
    let openEndedTotal: Int
    let vocabularyCorrect: Int
    let vocabularyTotal: Int
    let onDismiss: () -> Void
    
    private var accuracy: Double {
        guard totalPossiblePoints > 0 else { return 0.0 }
        return Double(totalPointsEarned) / Double(totalPossiblePoints)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Quiz Complete!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Great job completing all the questions!")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Points Summary
                VStack(spacing: 16) {
                    HStack {
                        Text("Total Points")
                            .font(.headline)
                        Spacer()
                        Text("\(totalPointsEarned)/\(totalPossiblePoints)")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    ProgressView(value: accuracy)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    
                    Text("\(Int(accuracy * 100))% Accuracy")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Detailed Results
                VStack(spacing: 12) {
                    ResultRow(
                        title: "Multiple Choice",
                        correct: multipleChoiceCorrect,
                        total: multipleChoiceTotal,
                        pointsPerQuestion: 8,
                        color: .blue
                    )
                    
                    ResultRow(
                        title: "Open-Ended",
                        correct: openEndedCorrect,
                        total: openEndedTotal,
                        pointsPerQuestion: 10,
                        color: .green
                    )
                    
                    ResultRow(
                        title: "Vocabulary",
                        correct: vocabularyCorrect,
                        total: vocabularyTotal,
                        pointsPerQuestion: 2,
                        color: .orange
                    )
                }
                
                Spacer()
                
                // Dismiss Button
                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

struct ResultRow: View {
    let title: String
    let correct: Int
    let total: Int
    let pointsPerQuestion: Int
    let color: Color
    
    private var pointsEarned: Int {
        return correct * pointsPerQuestion
    }
    
    private var totalPoints: Int {
        return total * pointsPerQuestion
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(correct)/\(total) correct")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(pointsEarned) pts")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                
                Text("of \(totalPoints)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Supporting Types and Views

enum QuestionSection: String, CaseIterable {
    case multipleChoice = "Multiple Choice"
    case openEnded = "Open-Ended"
    case vocabulary = "Vocabulary Practice"
    
    var icon: String {
        switch self {
        case .multipleChoice:
            return "list.bullet.circle"
        case .openEnded:
            return "text.bubble"
        case .vocabulary:
            return "book.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .multipleChoice:
            return .blue
        case .openEnded:
            return .green
        case .vocabulary:
            return .orange
        }
    }
}

struct ProgressIndicatorView: View {
    let currentSection: Int
    let totalSections: Int
    let currentQuestion: Int
    let totalQuestions: Int
    
    var body: some View {
        VStack(spacing: 8) {
            // Section progress
            HStack {
                Text("Section \(currentSection + 1) of \(totalSections)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Question \(currentQuestion) of \(totalQuestions)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * CGFloat(currentQuestion) / CGFloat(totalQuestions), height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

struct NavigationControlsView: View {
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onShowArticle: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onPrevious) {
                HStack {
                    Image(systemName: "chevron.left")
                }
                .foregroundColor(canGoPrevious ? .blue : .gray)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(canGoPrevious ? Color.blue : Color.gray, lineWidth: 1)
                )
            }
            .disabled(!canGoPrevious)
            .frame(width: 60)
            
            Spacer()
            
            Button(action: onShowArticle) {
                HStack {
                    Image(systemName: "doc.text")
                    Text("See Reading")
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 1)
                )
            }
            
            Spacer()
            
            Button(action: onNext) {
                HStack {
                    Image(systemName: "chevron.right")
                }
                .foregroundColor(canGoNext ? .white : .gray)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(canGoNext ? Color.blue : Color.gray)
                )
            }
            .disabled(!canGoNext)
            .frame(width: 60)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4)),
            alignment: .top
        )
    }
}

struct QuestionContentView: View {
    let section: QuestionSection
    let question: Any
    let questionIndex: Int
    @Binding var selectedAnswers: [String: String]
    @Binding var openEndedAnswers: [String: String]
    @Binding var editingAnswers: [String: String]
    @Binding var lockedAnswers: Set<String>
    @Binding var recordingQuestion: String?
    @Binding var vocabularyAnswers: [String: String]
    @Binding var vocabularyEditingAnswers: [String: String]
    @Binding var vocabularyLockedAnswers: Set<String>
    @Binding var recordingVocabularyWord: String?
    let speechManager: SpeechRecognitionManager
    let onWordTap: (String) -> Void
    let onMultipleChoiceAnswer: (Bool) -> Void
    let onOpenEndedAnswer: (Bool) -> Void
    let onVocabularyAnswer: (Bool) -> Void
    let articleContent: String
    let evaluateWithLLM: (String, String, String, String, Int) async -> Bool
    let evaluateOpenEndedAnswer: (String, String) -> Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question content based on section type
            switch section {
            case .multipleChoice:
                if let mcQuestion = question as? MultipleChoiceQuestion {
                    MultipleChoiceQuestionView(
                        question: mcQuestion,
                        questionNumber: questionIndex + 1,
                        selectedAnswer: selectedAnswers[mcQuestion.questionText],
                        onAnswerSelected: { answer in
                            selectedAnswers[mcQuestion.questionText] = answer
                            // Track if answer is correct
                            // Convert the answer reference (A, B, C, D) to the actual choice text
                            let correctAnswerText = getCorrectAnswerText(for: mcQuestion)
                            let isCorrect = answer == correctAnswerText
                            onMultipleChoiceAnswer(isCorrect)
                            
                            // Debug logging
                            print("Multiple Choice Question: \(mcQuestion.questionText)")
                            print("Selected Answer: \(answer)")
                            print("Correct Answer Reference: \(mcQuestion.answer)")
                            print("Correct Answer Text: \(correctAnswerText)")
                            print("Is Correct: \(isCorrect)")
                        }
                    )
                }
            case .openEnded:
                if let oeQuestion = question as? ComprehensionQuestion {
                    OpenEndedQuestionView(
                        questionNumber: questionIndex + 1,
                        question: oeQuestion,
                        answer: openEndedAnswers[oeQuestion.questionText] ?? "",
                        editingAnswer: editingAnswers[oeQuestion.questionText] ?? "",
                        isLocked: lockedAnswers.contains(oeQuestion.questionText),
                        isRecording: recordingQuestion == oeQuestion.questionText,
                        transcribedText: speechManager.transcribedText,
                        onStartRecording: {
                            startRecording(for: oeQuestion.questionText)
                        },
                        onStopRecording: {
                            stopRecording(for: oeQuestion.questionText)
                        },
                        onAnswerChanged: { newAnswer in
                            editingAnswers[oeQuestion.questionText] = newAnswer
                        },
                        onLockAnswer: {
                            lockAnswer(for: oeQuestion.questionText)
                            // Evaluate open-ended answer using LLM
                            let userAnswer = openEndedAnswers[oeQuestion.questionText] ?? ""
                            let expectedAnswer = oeQuestion.answer
                            
                            // Use LLM evaluation if article content is available
                            if !articleContent.isEmpty {
                                Task {
                                    let isCorrect = await evaluateWithLLM(
                                        articleContent,
                                        oeQuestion.questionText,
                                        expectedAnswer,
                                        userAnswer,
                                        questionIndex + 1
                                    )
                                    
                                    await MainActor.run {
                                        onOpenEndedAnswer(isCorrect)
                                        
                                        // Debug logging
                                        print("Open-Ended Question (LLM): \(oeQuestion.questionText)")
                                        print("User Answer: \(userAnswer)")
                                        print("Expected Answer: \(expectedAnswer)")
                                        print("Is Correct: \(isCorrect)")
                                    }
                                }
                            } else {
                                // Fallback to simple evaluation
                                let isCorrect = evaluateOpenEndedAnswer(userAnswer, expectedAnswer)
                                onOpenEndedAnswer(isCorrect)
                                
                                // Debug logging
                                print("Open-Ended Question (Simple): \(oeQuestion.questionText)")
                                print("User Answer: \(userAnswer)")
                                print("Expected Answer: \(expectedAnswer)")
                                print("Is Correct: \(isCorrect)")
                            }
                        },
                        onUnlockAnswer: {
                            unlockAnswer(for: oeQuestion.questionText)
                        }
                    )
                }
            case .vocabulary:
                if let word = question as? String {
                    VocabularyWordView(
                        wordNumber: questionIndex + 1,
                        word: word,
                        answer: vocabularyAnswers[word] ?? "",
                        editingAnswer: vocabularyEditingAnswers[word] ?? "",
                        isLocked: vocabularyLockedAnswers.contains(word),
                        isRecording: recordingVocabularyWord == word,
                        transcribedText: speechManager.transcribedText,
                        onWordTap: {
                            onWordTap(word)
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
                            // Track vocabulary answer as correct if it has content
                            let hasAnswer = !(vocabularyAnswers[word] ?? "").isEmpty
                            onVocabularyAnswer(hasAnswer)
                        },
                        onUnlockAnswer: {
                            unlockVocabularyAnswer(for: word)
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // Helper functions for recording
    private func startRecording(for questionText: String) {
        recordingQuestion = questionText
        speechManager.startListening()
    }
    
    private func stopRecording(for questionText: String) {
        recordingQuestion = nil
        speechManager.stopListening()
        openEndedAnswers[questionText] = editingAnswers[questionText] ?? ""
    }
    
    private func lockAnswer(for questionText: String) {
        lockedAnswers.insert(questionText)
        openEndedAnswers[questionText] = editingAnswers[questionText] ?? ""
    }
    
    private func unlockAnswer(for questionText: String) {
        lockedAnswers.remove(questionText)
    }
    
    private func startVocabularyRecording(for word: String) {
        recordingVocabularyWord = word
        speechManager.startListening()
    }
    
    private func stopVocabularyRecording(for word: String) {
        recordingVocabularyWord = nil
        speechManager.stopListening()
        vocabularyAnswers[word] = vocabularyEditingAnswers[word] ?? ""
    }
    
    private func lockVocabularyAnswer(for word: String) {
        vocabularyLockedAnswers.insert(word)
        vocabularyAnswers[word] = vocabularyEditingAnswers[word] ?? ""
    }
    
    private func unlockVocabularyAnswer(for word: String) {
        vocabularyLockedAnswers.remove(word)
    }
}

// MARK: - Custom TextEditor with Cursor Position Preservation

struct TextEditor: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let isDisabled: Bool
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = UIColor.systemGray6
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.isEditable = !isDisabled
        textView.isScrollEnabled = true
        textView.text = text.isEmpty ? placeholder : text
        textView.textColor = text.isEmpty ? UIColor.placeholderText : UIColor.label
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        // Only update text if it's different and preserve cursor position
        if textView.text != text {
            let currentPosition = textView.selectedTextRange
            textView.text = text.isEmpty ? placeholder : text
            textView.textColor = text.isEmpty ? UIColor.placeholderText : UIColor.label
            
            // Restore cursor position if it was valid
            if let position = currentPosition {
                textView.selectedTextRange = position
            }
        }
        
        textView.isEditable = !isDisabled
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: TextEditor
        
        init(_ parent: TextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            let newText = textView.text == parent.placeholder ? "" : (textView.text ?? "")
            parent.text = newText
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.text == parent.placeholder {
                textView.text = ""
                textView.textColor = UIColor.label
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            if (textView.text ?? "").isEmpty {
                textView.text = parent.placeholder
                textView.textColor = UIColor.placeholderText
            }
        }
    }
}

struct MultipleChoiceQuestionView: View {
    let question: MultipleChoiceQuestion
    let questionNumber: Int
    let selectedAnswer: String?
    let onAnswerSelected: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question header
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
            
            // Choices
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
                            onAnswerSelected(choice)
                        }) {
                            HStack {
                                Text(choice)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                if selectedAnswer == choice {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedAnswer == choice ?
                                        Color.blue.opacity(0.1) : Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedAnswer == choice ?
                                                Color.blue : Color.clear, lineWidth: 2)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
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
                        
                        TextEditor(
                            text: Binding(
                                get: { editingAnswer },
                                set: { onAnswerChanged($0) }
                            ),
                            placeholder: "Start recording or type your answer...",
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
                        
                        TextEditor(
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

struct ArticleView: View {
    let articleId: String
    let practiceSession: ReadingSession?
    @StateObject private var viewModel = ArticleViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if let session = practiceSession {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(session.paragraph.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            Text(session.paragraph.text)
                                .font(.body)
                                .lineSpacing(4)
                                .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                } else {
                    VStack {
                        ProgressView("Loading article...")
                            .padding()
                    }
                }
            }
            .navigationTitle("Article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Load article data if needed
            if practiceSession == nil {
                // Handle case where we need to load article data
                // This would depend on your data structure
            }
        }
    }
}
