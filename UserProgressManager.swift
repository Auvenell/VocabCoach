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
    
    init() {
        setupAuthListener()
    }
    
    // MARK: - Authentication Listener
    
    private func setupAuthListener() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
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
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: data)
                        self?.currentProgress = try JSONDecoder().decode(UserProgress.self, from: jsonData)
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
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
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
    
    func saveReadingSession(_ session: UserReadingSession) {
        do {
            let data = try JSONEncoder().encode(session)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            db.collection("reading_sessions").document(session.sessionId).setData(dict) { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                    } else {
                        self?.updateUserProgressAfterSession(session)
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
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
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
    
    // Convenience function to create and save question sessions with points
    func saveQuestionSessionWithPoints(
        userId: String,
        articleId: String,
        questionType: QuestionSession.QuestionType,
        totalQuestions: Int,
        correctAnswers: Int,
        timeSpent: TimeInterval,
        completed: Bool = true
    ) {
        let (totalPoints, earnedPoints) = calculateQuestionSessionPoints(
            questionType: questionType,
            totalQuestions: totalQuestions,
            correctAnswers: correctAnswers
        )
        
        let accuracy = totalQuestions > 0 ? Double(correctAnswers) / Double(totalQuestions) : 0.0
        
        let session = QuestionSession(
            sessionId: UUID().uuidString,
            userId: userId,
            articleId: articleId,
            questionType: questionType,
            totalQuestions: totalQuestions,
            correctAnswers: correctAnswers,
            accuracy: accuracy,
            timeSpent: timeSpent,
            completed: completed,
            totalPoints: totalPoints,
            earnedPoints: earnedPoints,
            createdAt: Date()
        )
        
        saveQuestionSession(session)
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
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
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
    
    private func updateUserProgressAfterSession(_ session: UserReadingSession) {
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
    
    func getWordMasteryProgress(userId: String, completion: @escaping ([WordProgress]) -> Void) {
        db.collection("word_progress")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                let wordProgress = documents.compactMap { doc -> WordProgress? in
                    do {
                        let data = try JSONSerialization.data(withJSONObject: doc.data())
                        return try JSONDecoder().decode(WordProgress.self, from: data)
                    } catch {
                        return nil
                    }
                }
                
                completion(wordProgress)
            }
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
} 