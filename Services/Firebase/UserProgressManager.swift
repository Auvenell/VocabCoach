import FirebaseFirestore
import FirebaseAuth
import Foundation
import Combine

// MARK: - Data Models

struct UserProgress: Codable {
    let userId: String
    var totalSessions: Int
    var totalWordsRead: Int
    var totalWordsCorrect: Int
    var averageAccuracy: Double
    var totalTimeSpent: TimeInterval
    var totalPoints: Int
    var earnedPoints: Int
    var lastActiveDate: Date
    var streakDays: Int
    var level: UserLevel
    let createdAt: Date
    var updatedAt: Date
    
    enum UserLevel: String, Codable, CaseIterable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        case expert = "Expert"
        
        var requiredAccuracy: Double {
            switch self {
            case .beginner: return 0.0
            case .intermediate: return 0.7
            case .advanced: return 0.85
            case .expert: return 0.95
            }
        }
    }
}

struct UserReadingSession: Codable {
    let sessionId: String
    let userId: String
    let articleId: String
    let articleTitle: String
    let difficulty: String
    let category: String
    let startTime: Date
    let endTime: Date?
    let totalWords: Int
    let correctWords: Int
    let accuracy: Double
    let timeSpent: TimeInterval
    let wordsToReview: [String]
    let completed: Bool
    let createdAt: Date
}

struct QuestionSession: Codable {
    let sessionId: String
    let userId: String
    let articleId: String
    let questionType: QuestionType
    let totalQuestions: Int
    let correctAnswers: Int
    let accuracy: Double
    let timeSpent: TimeInterval
    let completed: Bool
    let totalPoints: Int
    let earnedPoints: Int
    let createdAt: Date
    
    enum QuestionType: String, Codable {
        case multipleChoice = "multiple_choice"
        case openEnded = "open_ended"
        case vocabulary = "vocabulary"
        
        var pointsPerQuestion: Int {
            switch self {
            case .multipleChoice: return 8
            case .openEnded: return 10
            case .vocabulary: return 2
            }
        }
    }
}

// New combined session structure with nested collections
struct CombinedQuestionSession: Codable {
    let sessionId: String
    let userId: String
    let articleId: String
    let articleTitle: String
    let totalTimeSpent: TimeInterval
    let completed: Bool
    let totalPoints: Int
    let earnedPoints: Int
    let createdAt: Date
    let accuracy: Double
    
    // Nested session data for each question type
    let multipleChoiceSession: QuestionTypeSession?
    let openEndedSession: QuestionTypeSession?
    let vocabularySession: QuestionTypeSession?
}

struct QuestionTypeSession: Codable {
    let questionType: QuestionSession.QuestionType
    let totalQuestions: Int
    let correctAnswers: Int
    let accuracy: Double
    let timeSpent: TimeInterval
    let totalPoints: Int
    let earnedPoints: Int
}

struct WordProgress: Codable {
    let userId: String
    let word: String
    var totalAttempts: Int
    var correctAttempts: Int
    var lastPracticed: Date
    var difficulty: WordDifficulty
    var masteryLevel: MasteryLevel
    
    enum WordDifficulty: String, Codable {
        case easy = "easy"
        case medium = "medium"
        case hard = "hard"
    }
    
    enum MasteryLevel: String, Codable {
        case new = "new"
        case learning = "learning"
        case mastered = "mastered"
        case needsReview = "needs_review"
    }
}

struct UserAnalytics: Codable {
    let userId: String
    let dailyStats: [DailyStats]
    let weeklyStats: [WeeklyStats]
    let monthlyStats: [MonthlyStats]
    
    struct DailyStats: Codable {
        let date: Date
        let sessionsCompleted: Int
        let wordsRead: Int
        let accuracy: Double
        let timeSpent: TimeInterval
    }
    
    struct WeeklyStats: Codable {
        let weekStart: Date
        let sessionsCompleted: Int
        let averageAccuracy: Double
        let totalTimeSpent: TimeInterval
        let streakDays: Int
    }
    
    struct MonthlyStats: Codable {
        let month: Date
        let sessionsCompleted: Int
        let averageAccuracy: Double
        let totalTimeSpent: TimeInterval
        let level: UserProgress.UserLevel
    }
}

// MARK: - User Progress Manager

class UserProgressManager: ObservableObject {
    @Published var currentProgress: UserProgress?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    init() {
        setupAuthListener()
    }
    
    deinit {
        // Remove the auth state listener when the object is deallocated
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Authentication Listener
    
    private func setupAuthListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                self?.loadUserProgress(userId: user.uid)
            } else {
                self?.currentProgress = nil
            }
        }
    }
    
    // MARK: - User Progress Management
    
    func loadUserProgress(userId: String) {
        isLoading = true
        
        db.collection("user_progress").document(userId).getDocument { [weak self] snapshot, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                if let data = snapshot?.data() {
                    // Convert Firestore data to JSON-serializable format
                    var serializableData: [String: Any] = [:]
                    
                    for (key, value) in data {
                        if let timestamp = value as? Timestamp {
                            // Convert FIRTimestamp to ISO8601 string
                            let date = timestamp.dateValue()
                            let formatter = ISO8601DateFormatter()
                            serializableData[key] = formatter.string(from: date)
                        } else {
                            serializableData[key] = value
                        }
                    }
                    
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: serializableData)
                        
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        
                        self?.currentProgress = try decoder.decode(UserProgress.self, from: jsonData)
                    } catch {
                        self?.errorMessage = "Failed to decode user progress: \(error.localizedDescription)"
                    }
                } else {
                    // Create new user progress
                    self?.createNewUserProgress(userId: userId)
                }
            }
        }
    }
    
    private func createNewUserProgress(userId: String) {
        let newProgress = UserProgress(
            userId: userId,
            totalSessions: 0,
            totalWordsRead: 0,
            totalWordsCorrect: 0,
            averageAccuracy: 0.0,
            totalTimeSpent: 0,
            totalPoints: 0,
            earnedPoints: 0,
            lastActiveDate: Date(),
            streakDays: 0,
            level: .beginner,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        saveUserProgress(newProgress)
    }
    
    private func saveUserProgress(_ progress: UserProgress) {
        do {
            let data = try JSONEncoder().encode(progress)
            var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            // Convert date fields to Firestore Timestamps
            dict["createdAt"] = Timestamp(date: progress.createdAt)
            dict["updatedAt"] = Timestamp(date: progress.updatedAt)
            dict["lastActiveDate"] = Timestamp(date: progress.lastActiveDate)
            
            db.collection("user_progress").document(progress.userId).setData(dict) { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                    } else {
                        self?.currentProgress = progress
                    }
                }
            }
        } catch {
            errorMessage = "Failed to encode user progress: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Session Tracking
    
    // Helper function to calculate points for question sessions
    func calculateQuestionSessionPoints(
        questionType: QuestionSession.QuestionType,
        totalQuestions: Int,
        correctAnswers: Int
    ) -> (totalPoints: Int, earnedPoints: Int) {
        let totalPoints = totalQuestions * questionType.pointsPerQuestion
        let earnedPoints = correctAnswers * questionType.pointsPerQuestion
        return (totalPoints, earnedPoints)
    }
    
    // Helper function to calculate points for open-ended questions based on scores
    func calculateOpenEndedSessionPoints(
        totalQuestions: Int,
        scores: [Double]
    ) -> (totalPoints: Int, earnedPoints: Int) {
        let totalPoints = totalQuestions * QuestionSession.QuestionType.openEnded.pointsPerQuestion
        let earnedPoints = Int(scores.reduce(0, +) * Double(QuestionSession.QuestionType.openEnded.pointsPerQuestion))
        return (totalPoints, earnedPoints)
    }
    
    func saveReadingSession(_ session: UserReadingSession) {
        do {
            let data = try JSONEncoder().encode(session)
            var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            // Convert date fields to Firestore Timestamps
            dict["createdAt"] = Timestamp(date: session.createdAt)
            dict["startTime"] = Timestamp(date: session.startTime)
            if let endTime = session.endTime {
                dict["endTime"] = Timestamp(date: endTime)
            }
            
            db.collection("reading_sessions").document(session.sessionId).setData(dict) { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                    } else {
                        self?.updateUserProgressAfterReadingSession(session)
                    }
                }
            }
        } catch {
            errorMessage = "Failed to encode reading session: \(error.localizedDescription)"
        }
    }
    
    func saveQuestionSession(_ session: QuestionSession) {
        do {
            let data = try JSONEncoder().encode(session)
            var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            // Convert createdAt to Firestore Timestamp
            dict["createdAt"] = Timestamp(date: session.createdAt)
            
            db.collection("question_sessions").document(session.sessionId).setData(dict) { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                    } else {
                        self?.updateUserProgressAfterQuestionSession(session)
                    }
                }
            }
        } catch {
            errorMessage = "Failed to encode question session: \(error.localizedDescription)"
        }
    }
    
    
    // New method to save combined question session with nested collections
    func saveCombinedQuestionSession(
        userId: String,
        articleId: String,
        articleTitle: String,
        multipleChoiceData: (totalQuestions: Int, correctAnswers: Int, timeSpent: TimeInterval)?,
        openEndedData: (totalQuestions: Int, correctAnswers: Int, timeSpent: TimeInterval, scores: [Double])?,
        vocabularyData: (totalQuestions: Int, correctAnswers: Int, timeSpent: TimeInterval)?,
        completed: Bool = true,
        sessionId: String? = nil
    ) -> String {
        let sessionId = sessionId ?? UUID().uuidString
        let createdAt = Date()
        
        // Calculate individual session data
        var multipleChoiceSession: QuestionTypeSession?
        var openEndedSession: QuestionTypeSession?
        var vocabularySession: QuestionTypeSession?
        
        var totalPoints = 0
        var earnedPoints = 0
        var totalTimeSpent: TimeInterval = 0
        var totalCorrectAnswers = 0
        var totalQuestions = 0
        
        // Process multiple choice data
        if let mcData = multipleChoiceData {
            let (mcTotalPoints, mcEarnedPoints) = calculateQuestionSessionPoints(
                questionType: .multipleChoice,
                totalQuestions: mcData.totalQuestions,
                correctAnswers: mcData.correctAnswers
            )
            
            multipleChoiceSession = QuestionTypeSession(
                questionType: .multipleChoice,
                totalQuestions: mcData.totalQuestions,
                correctAnswers: mcData.correctAnswers,
                accuracy: mcData.totalQuestions > 0 ? Double(mcData.correctAnswers) / Double(mcData.totalQuestions) : 0.0,
                timeSpent: mcData.timeSpent,
                totalPoints: mcTotalPoints,
                earnedPoints: mcEarnedPoints
            )
            
            totalPoints += mcTotalPoints
            earnedPoints += mcEarnedPoints
            totalTimeSpent += mcData.timeSpent
            totalCorrectAnswers += mcData.correctAnswers
            totalQuestions += mcData.totalQuestions
        }
        
        // Process open-ended data
        if let oeData = openEndedData {
            let (oeTotalPoints, oeEarnedPoints) = calculateOpenEndedSessionPoints(
                totalQuestions: oeData.totalQuestions,
                scores: oeData.scores
            )
            
            // Calculate accuracy based on average score
            let averageScore = oeData.scores.isEmpty ? 0.0 : oeData.scores.reduce(0, +) / Double(oeData.scores.count)
            
            openEndedSession = QuestionTypeSession(
                questionType: .openEnded,
                totalQuestions: oeData.totalQuestions,
                correctAnswers: oeData.correctAnswers,
                accuracy: averageScore,
                timeSpent: oeData.timeSpent,
                totalPoints: oeTotalPoints,
                earnedPoints: oeEarnedPoints
            )
            
            totalPoints += oeTotalPoints
            earnedPoints += oeEarnedPoints
            totalTimeSpent += oeData.timeSpent
            totalCorrectAnswers += oeData.correctAnswers
            totalQuestions += oeData.totalQuestions
        }
        
        // Process vocabulary data
        if let vocabData = vocabularyData {
            let (vocabTotalPoints, vocabEarnedPoints) = calculateQuestionSessionPoints(
                questionType: .vocabulary,
                totalQuestions: vocabData.totalQuestions,
                correctAnswers: vocabData.correctAnswers
            )
            
            vocabularySession = QuestionTypeSession(
                questionType: .vocabulary,
                totalQuestions: vocabData.totalQuestions,
                correctAnswers: vocabData.correctAnswers,
                accuracy: vocabData.totalQuestions > 0 ? Double(vocabData.correctAnswers) / Double(vocabData.totalQuestions) : 0.0,
                timeSpent: vocabData.timeSpent,
                totalPoints: vocabTotalPoints,
                earnedPoints: vocabEarnedPoints
            )
            
            totalPoints += vocabTotalPoints
            earnedPoints += vocabEarnedPoints
            totalTimeSpent += vocabData.timeSpent
            totalCorrectAnswers += vocabData.correctAnswers
            totalQuestions += vocabData.totalQuestions
        }
        
        // Calculate overall accuracy
        let overallAccuracy = totalQuestions > 0 ? Double(totalCorrectAnswers) / Double(totalQuestions) : 0.0
        
        // Create combined session
        let combinedSession = CombinedQuestionSession(
            sessionId: sessionId,
            userId: userId,
            articleId: articleId,
            articleTitle: articleTitle,
            totalTimeSpent: totalTimeSpent,
            completed: completed,
            totalPoints: totalPoints,
            earnedPoints: earnedPoints,
            createdAt: createdAt,
            accuracy: overallAccuracy,
            multipleChoiceSession: multipleChoiceSession,
            openEndedSession: openEndedSession,
            vocabularySession: vocabularySession
        )
        
        saveCombinedQuestionSessionToFirestore(combinedSession)
        return sessionId
    }
    
    // Update existing question session with final data
    func updateQuestionSession(
        sessionId: String,
        userId: String,
        articleId: String,
        articleTitle: String,
        multipleChoiceData: (totalQuestions: Int, correctAnswers: Int, timeSpent: TimeInterval)?,
        openEndedData: (totalQuestions: Int, correctAnswers: Int, timeSpent: TimeInterval, scores: [Double])?,
        vocabularyData: (totalQuestions: Int, correctAnswers: Int, timeSpent: TimeInterval)?,
        completed: Bool = true
    ) -> (totalPoints: Int, earnedPoints: Int) {
        let createdAt = Date()
        
        // Calculate individual session data
        var multipleChoiceSession: QuestionTypeSession?
        var openEndedSession: QuestionTypeSession?
        var vocabularySession: QuestionTypeSession?
        
        var totalPoints = 0
        var earnedPoints = 0
        var totalTimeSpent: TimeInterval = 0
        var totalCorrectAnswers = 0
        var totalQuestions = 0
        
        // Process multiple choice data
        if let mcData = multipleChoiceData {
            let (mcTotalPoints, mcEarnedPoints) = calculateQuestionSessionPoints(
                questionType: .multipleChoice,
                totalQuestions: mcData.totalQuestions,
                correctAnswers: mcData.correctAnswers
            )
            
            multipleChoiceSession = QuestionTypeSession(
                questionType: .multipleChoice,
                totalQuestions: mcData.totalQuestions,
                correctAnswers: mcData.correctAnswers,
                accuracy: mcData.totalQuestions > 0 ? Double(mcData.correctAnswers) / Double(mcData.totalQuestions) : 0.0,
                timeSpent: mcData.timeSpent,
                totalPoints: mcTotalPoints,
                earnedPoints: mcEarnedPoints
            )
            
            totalPoints += mcTotalPoints
            earnedPoints += mcEarnedPoints
            totalTimeSpent += mcData.timeSpent
            totalCorrectAnswers += mcData.correctAnswers
            totalQuestions += mcData.totalQuestions
        }
        
        // Process open-ended data
        if let oeData = openEndedData {
            let (oeTotalPoints, oeEarnedPoints) = calculateOpenEndedSessionPoints(
                totalQuestions: oeData.totalQuestions,
                scores: oeData.scores
            )
            
            // Calculate accuracy based on average score
            let averageScore = oeData.scores.isEmpty ? 0.0 : oeData.scores.reduce(0, +) / Double(oeData.scores.count)
            
            openEndedSession = QuestionTypeSession(
                questionType: .openEnded,
                totalQuestions: oeData.totalQuestions,
                correctAnswers: oeData.correctAnswers,
                accuracy: averageScore,
                timeSpent: oeData.timeSpent,
                totalPoints: oeTotalPoints,
                earnedPoints: oeEarnedPoints
            )
            
            totalPoints += oeTotalPoints
            earnedPoints += oeEarnedPoints
            totalTimeSpent += oeData.timeSpent
            totalCorrectAnswers += oeData.correctAnswers
            totalQuestions += oeData.totalQuestions
        }
        
        // Process vocabulary data
        if let vocabData = vocabularyData {
            let (vocabTotalPoints, vocabEarnedPoints) = calculateQuestionSessionPoints(
                questionType: .vocabulary,
                totalQuestions: vocabData.totalQuestions,
                correctAnswers: vocabData.correctAnswers
            )
            
            vocabularySession = QuestionTypeSession(
                questionType: .vocabulary,
                totalQuestions: vocabData.totalQuestions,
                correctAnswers: vocabData.correctAnswers,
                accuracy: vocabData.totalQuestions > 0 ? Double(vocabData.correctAnswers) / Double(vocabData.totalQuestions) : 0.0,
                timeSpent: vocabData.timeSpent,
                totalPoints: vocabTotalPoints,
                earnedPoints: vocabEarnedPoints
            )
            
            totalPoints += vocabTotalPoints
            earnedPoints += vocabEarnedPoints
            totalTimeSpent += vocabData.timeSpent
            totalCorrectAnswers += vocabData.correctAnswers
            totalQuestions += vocabData.totalQuestions
        }
        
        // Calculate overall accuracy
        let overallAccuracy = totalQuestions > 0 ? Double(totalCorrectAnswers) / Double(totalQuestions) : 0.0
        
        // Create combined session
        let combinedSession = CombinedQuestionSession(
            sessionId: sessionId,
            userId: userId,
            articleId: articleId,
            articleTitle: articleTitle,
            totalTimeSpent: totalTimeSpent,
            completed: completed,
            totalPoints: totalPoints,
            earnedPoints: earnedPoints,
            createdAt: createdAt,
            accuracy: overallAccuracy,
            multipleChoiceSession: multipleChoiceSession,
            openEndedSession: openEndedSession,
            vocabularySession: vocabularySession
        )
        
        updateCombinedQuestionSession(combinedSession)
        return (totalPoints: totalPoints, earnedPoints: earnedPoints)
    }
    
    private func saveCombinedQuestionSessionToFirestore(_ session: CombinedQuestionSession) {
        do {
            let data = try JSONEncoder().encode(session)
            var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            // Convert createdAt to Firestore Timestamp
            dict["createdAt"] = Timestamp(date: session.createdAt)
            
            db.collection("question_sessions").document(session.sessionId).setData(dict) { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                    } else {
                        self?.updateUserProgressAfterCombinedSession(session)
                    }
                }
            }
        } catch {
            errorMessage = "Failed to encode combined question session: \(error.localizedDescription)"
        }
    }
    
    private func updateCombinedQuestionSession(_ session: CombinedQuestionSession) {
        do {
            let data = try JSONEncoder().encode(session)
            var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            // Convert createdAt to Firestore Timestamp
            dict["createdAt"] = Timestamp(date: session.createdAt)
            
            db.collection("question_sessions").document(session.sessionId).updateData(dict) { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                    } else {
                        self?.updateUserProgressAfterCombinedSession(session)
                    }
                }
            }
        } catch {
            errorMessage = "Failed to encode combined question session: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Word Progress Tracking
    
    func updateWordProgress(userId: String, word: String, isCorrect: Bool) {
        let wordRef = db.collection("word_progress").document("\(userId)_\(word.lowercased())")
        
        wordRef.getDocument { [weak self] snapshot, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
                return
            }
            
            var wordProgress: WordProgress
            
            if let data = snapshot?.data() {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: data)
                    wordProgress = try JSONDecoder().decode(WordProgress.self, from: jsonData)
                } catch {
                    // Create new word progress if decoding fails
                    wordProgress = WordProgress(
                        userId: userId,
                        word: word,
                        totalAttempts: 0,
                        correctAttempts: 0,
                        lastPracticed: Date(),
                        difficulty: .medium,
                        masteryLevel: .new
                    )
                }
            } else {
                // Create new word progress
                wordProgress = WordProgress(
                    userId: userId,
                    word: word,
                    totalAttempts: 0,
                    correctAttempts: 0,
                    lastPracticed: Date(),
                    difficulty: .medium,
                    masteryLevel: .new
                )
            }
            
            // Update word progress
            wordProgress.totalAttempts += 1
            if isCorrect {
                wordProgress.correctAttempts += 1
            }
            wordProgress.lastPracticed = Date()
            
            // Update mastery level based on accuracy
            let accuracy = Double(wordProgress.correctAttempts) / Double(wordProgress.totalAttempts)
            wordProgress.masteryLevel = self?.calculateMasteryLevel(accuracy: accuracy) ?? .new
            
            // Save updated word progress
            self?.saveWordProgress(wordProgress)
        }
    }
    
    private func calculateMasteryLevel(accuracy: Double) -> WordProgress.MasteryLevel {
        switch accuracy {
        case 0.0..<0.3:
            return .new
        case 0.3..<0.7:
            return .learning
        case 0.7..<0.9:
            return .needsReview
        default:
            return .mastered
        }
    }
    
    private func saveWordProgress(_ wordProgress: WordProgress) {
        do {
            let data = try JSONEncoder().encode(wordProgress)
            var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            // Convert lastPracticed to Firestore Timestamp
            dict["lastPracticed"] = Timestamp(date: wordProgress.lastPracticed)
            
            let wordRef = db.collection("word_progress").document("\(wordProgress.userId)_\(wordProgress.word.lowercased())")
            wordRef.setData(dict) { [weak self] error in
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                }
            }
        } catch {
            errorMessage = "Failed to encode word progress: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Progress Updates
    
    private func updateUserProgressAfterReadingSession(_ session: UserReadingSession) {
        guard var progress = currentProgress else { return }
        
        progress.totalSessions += 1
        progress.totalWordsRead += session.totalWords
        progress.totalWordsCorrect += session.correctWords
        progress.totalTimeSpent += session.timeSpent
        progress.lastActiveDate = Date()
        
        // Update average accuracy
        let totalAccuracy = (progress.averageAccuracy * Double(progress.totalSessions - 1)) + session.accuracy
        progress.averageAccuracy = totalAccuracy / Double(progress.totalSessions)
        
        // Update streak
        progress.streakDays = calculateStreakDays(currentDate: Date(), lastActive: progress.lastActiveDate, currentStreak: progress.streakDays)
        
        // Update level
        progress.level = calculateUserLevel(accuracy: progress.averageAccuracy, sessions: progress.totalSessions)
        progress.updatedAt = Date()
        
        saveUserProgress(progress)
    }
    
    private func updateUserProgressAfterQuestionSession(_ session: QuestionSession) {
        guard var progress = currentProgress else { return }
        
        progress.lastActiveDate = Date()
        progress.totalTimeSpent += session.timeSpent
        progress.totalPoints += session.totalPoints
        progress.earnedPoints += session.earnedPoints
        
        // Update streak
        progress.streakDays = calculateStreakDays(currentDate: Date(), lastActive: progress.lastActiveDate, currentStreak: progress.streakDays)
        
        progress.updatedAt = Date()
        
        saveUserProgress(progress)
    }
    
    private func updateUserProgressAfterCombinedSession(_ session: CombinedQuestionSession) {
        guard var progress = currentProgress else { return }
        
        progress.lastActiveDate = Date()
        progress.totalTimeSpent += session.totalTimeSpent
        progress.totalPoints += session.totalPoints
        progress.earnedPoints += session.earnedPoints
        
        // Update streak
        progress.streakDays = calculateStreakDays(currentDate: Date(), lastActive: progress.lastActiveDate, currentStreak: progress.streakDays)
        
        progress.updatedAt = Date()
        
        saveUserProgress(progress)
    }
    
    // MARK: - Analytics and Calculations
    
    private func calculateStreakDays(currentDate: Date, lastActive: Date, currentStreak: Int) -> Int {
        let calendar = Calendar.current
        let daysSinceLastActive = calendar.dateComponents([.day], from: lastActive, to: currentDate).day ?? 0
        
        if daysSinceLastActive == 0 {
            return currentStreak
        } else if daysSinceLastActive == 1 {
            return currentStreak + 1
        } else {
            return 1 // Reset streak
        }
    }
    
    private func calculateUserLevel(accuracy: Double, sessions: Int) -> UserProgress.UserLevel {
        // Consider both accuracy and experience
        if sessions < 5 {
            return .beginner
        } else if accuracy >= UserProgress.UserLevel.expert.requiredAccuracy {
            return .expert
        } else if accuracy >= UserProgress.UserLevel.advanced.requiredAccuracy {
            return .advanced
        } else if accuracy >= UserProgress.UserLevel.intermediate.requiredAccuracy {
            return .intermediate
        } else {
            return .beginner
        }
    }
    
    // MARK: - Analytics Queries
    
    func getWeeklyProgress(userId: String, completion: @escaping ([UserAnalytics.DailyStats]) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        
        db.collection("reading_sessions")
            .whereField("userId", isEqualTo: userId)
            .whereField("startTime", isGreaterThan: weekAgo)
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                let dailyStats = self.aggregateDailyStats(from: documents)
                completion(dailyStats)
            }
    }
    
    
    func getRecentQuestionSessions(userId: String, limit: Int = 3, completion: @escaping ([CombinedQuestionSession]) -> Void) {
        db.collection("question_sessions")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                let sessions = documents.compactMap { doc -> CombinedQuestionSession? in
                    do {
                        let serializableData = self.convertFirestoreData(doc.data())
                        let jsonData = try JSONSerialization.data(withJSONObject: serializableData)
                        
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        
                        return try decoder.decode(CombinedQuestionSession.self, from: jsonData)
                    } catch {
                        print("Error decoding session \(doc.documentID): \(error)")
                        return nil
                    }
                }
                
                completion(sessions)
            }
    }
    
    // MARK: - Helper Methods
    
    private func convertFirestoreData(_ data: [String: Any]) -> [String: Any] {
        var serializableData: [String: Any] = [:]
        
        for (key, value) in data {
            if let timestamp = value as? Timestamp {
                // Convert FIRTimestamp to ISO8601 string
                let date = timestamp.dateValue()
                let formatter = ISO8601DateFormatter()
                serializableData[key] = formatter.string(from: date)
            } else if let dict = value as? [String: Any] {
                // Handle nested dictionaries (like session objects)
                serializableData[key] = convertFirestoreData(dict)
            } else {
                serializableData[key] = value
            }
        }
        
        return serializableData
    }
    
    private func aggregateDailyStats(from documents: [QueryDocumentSnapshot]) -> [UserAnalytics.DailyStats] {
        let calendar = Calendar.current
        var dailyStats: [Date: UserAnalytics.DailyStats] = [:]
        
        for doc in documents {
            do {
                let data = try JSONSerialization.data(withJSONObject: doc.data())
                let session = try JSONDecoder().decode(UserReadingSession.self, from: data)
                
                let dayStart = calendar.startOfDay(for: session.startTime)
                
                if let existing = dailyStats[dayStart] {
                    dailyStats[dayStart] = UserAnalytics.DailyStats(
                        date: dayStart,
                        sessionsCompleted: existing.sessionsCompleted + 1,
                        wordsRead: existing.wordsRead + session.totalWords,
                        accuracy: (existing.accuracy + session.accuracy) / 2.0,
                        timeSpent: existing.timeSpent + session.timeSpent
                    )
                } else {
                    dailyStats[dayStart] = UserAnalytics.DailyStats(
                        date: dayStart,
                        sessionsCompleted: 1,
                        wordsRead: session.totalWords,
                        accuracy: session.accuracy,
                        timeSpent: session.timeSpent
                    )
                }
            } catch {
                continue
            }
        }
        
        return Array(dailyStats.values).sorted { $0.date < $1.date }
    }
    
    // Helper method to get article title
    func getArticleTitle(articleId: String, completion: @escaping (String) -> Void) {
        db.collection("articles").document(articleId).getDocument { snapshot, error in
            if let data = snapshot?.data(),
               let title = data["title"] as? String {
                completion(title)
            } else {
                completion("Unknown Article")
            }
        }
    }
} 