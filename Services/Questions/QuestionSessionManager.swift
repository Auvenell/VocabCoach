//
//  QuestionSessionManager.swift
//  VocabCoach
//
//  Created by Aunik Paul on 8/6/25.
//

import FirebaseFirestore
import FirebaseAuth
import Foundation

// MARK: - Question Session Management Service

class QuestionSessionManager: ObservableObject {
    @Published var questionSessionId: String?
    @Published var sessionStartTime: Date?
    @Published var multipleChoiceCorrect: Int = 0
    @Published var openEndedScores: [Double] = []
    @Published var vocabularyCorrect: Int = 0
    @Published var sessionCompleted: Bool = false
    @Published var multipleChoiceResponses: [MultipleChoiceQuestionResponse] = []
    @Published var openEndedResponses: [OpenEndedQuestionResponse] = []
    @Published var multipleChoiceSectionCompleted: Bool = false
    
    func startQuestionSession(sessionId: String? = nil) {
        sessionStartTime = Date()
        multipleChoiceCorrect = 0
        openEndedScores.removeAll()
        multipleChoiceResponses.removeAll()
        vocabularyCorrect = 0
        sessionCompleted = false
        
        // Create the question session document at the start
        createQuestionSessionDocument(sessionId: sessionId)
    }
    
    private func createQuestionSessionDocument(sessionId: String? = nil) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Use the passed sessionId if available, otherwise generate a new one
        let sessionId = sessionId ?? UUID().uuidString
        questionSessionId = sessionId
        
        // Create initial session document with basic info
        let initialSessionData: [String: Any] = [
            "sessionId": sessionId,
            "userId": userId,
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
    
    func trackMultipleChoiceAnswer(isCorrect: Bool, questionNumber: Int, questionText: String, studentChoice: String, correctChoice: String) {
        // Only track if multiple choice section is not completed
        guard !multipleChoiceSectionCompleted else { return }
        
        if isCorrect {
            multipleChoiceCorrect += 1
        }
        
        // Create detailed response
        let response = MultipleChoiceQuestionResponse(
            questionNumber: questionNumber,
            questionText: questionText,
            studentAnswer: studentChoice,
            correctAnswer: correctChoice,
            isCorrect: isCorrect,
            timestamp: Date()
        )
        
        // Add to responses array (but don't save to Firestore yet)
        multipleChoiceResponses.append(response)
    }
    
    func trackOpenEndedAnswer(score: Double) {
        openEndedScores.append(score)
    }
    
    func trackVocabularyAnswer(isCorrect: Bool) {
        if isCorrect {
            vocabularyCorrect += 1
        }
    }
    
    // Complete multiple choice section and save responses to Firestore
    func completeMultipleChoiceSection() {
        guard !multipleChoiceSectionCompleted else { return }
        
        multipleChoiceSectionCompleted = true
        
        // Save multiple choice responses to Firestore
        guard let userId = Auth.auth().currentUser?.uid,
              let sessionId = questionSessionId else { return }
        
        saveMultipleChoiceResponsesCollection(userId: userId, questionSessionId: sessionId)
    }
    
    func saveQuestionSessions(articleId: String, totalQuestions: Int) {
        guard let userId = Auth.auth().currentUser?.uid,
              let sessionId = questionSessionId,
              let startTime = sessionStartTime else { return }
        
        let endTime = Date()
        let timeSpent = Int(endTime.timeIntervalSince(startTime))
        
        // Calculate points earned and accuracy
        let pointsEarned = calculateTotalPointsEarned()
        let totalPossible = calculateTotalPossiblePoints(totalQuestions: totalQuestions)
        let accuracy = totalPossible > 0 ? Double(pointsEarned) / Double(totalPossible) : 0.0
        
        let sessionData: [String: Any] = [
            "sessionId": sessionId,
            "userId": userId,
            "articleId": articleId,
            "totalTimeSpent": timeSpent,
            "completed": true,
            "totalPoints": totalPossible,
            "earnedPoints": pointsEarned,
            "accuracy": accuracy,
            "multipleChoiceCorrect": multipleChoiceCorrect,
            "openEndedScores": openEndedScores,
            "vocabularyCorrect": vocabularyCorrect,
            "completedAt": Timestamp(date: endTime),
            "createdAt": Timestamp(date: startTime)
        ]
        
        let db = Firestore.firestore()
        db.collection("question_sessions").document(sessionId).updateData(sessionData) { error in
            if let error = error {
                print("Error saving question session: \(error.localizedDescription)")
            } else {
                print("Successfully saved question session: \(sessionId)")
            }
        }
        
        // Save responses collections
        saveOpenEndedResponsesCollection(userId: userId, questionSessionId: sessionId)
    }
    
    private func calculateTotalPointsEarned() -> Int {
        let multipleChoicePoints = multipleChoiceCorrect * 8
        let openEndedPoints = Int(openEndedScores.reduce(0, +) * 10)
        let vocabularyPoints = vocabularyCorrect * 2
        return multipleChoicePoints + openEndedPoints + vocabularyPoints
    }
    
    private func calculateTotalPossiblePoints(totalQuestions: Int) -> Int {
        // This would need to be passed in or calculated based on question counts
        // For now, using a simple calculation
        return totalQuestions * 8 // Assuming average of 8 points per question
    }
    
    // MARK: - Firebase Save Operations
    
    func saveOpenEndedResponse(_ response: OpenEndedQuestionResponse, articleId: String) {
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
            
            // Save to the nested structure within the question session
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
    
    private func saveOpenEndedResponsesCollection(userId: String, questionSessionId: String) {
        guard !openEndedResponses.isEmpty else { return }
        
        let db = Firestore.firestore()
        let batch = db.batch()
        
        for response in openEndedResponses {
            do {
                let data = try JSONEncoder().encode(response)
                var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                
                // Convert timestamp to Firestore Timestamp
                dict["timestamp"] = Timestamp(date: response.timestamp)
                dict["userId"] = userId
                
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
        batch.commit { [self] error in
            if let error = error {
                print("Error saving open-ended responses: \(error.localizedDescription)")
            } else {
                print("Successfully saved \(self.openEndedResponses.count) open-ended responses")
            }
        }
    }
    
    private func saveMultipleChoiceResponsesCollection(userId: String, questionSessionId: String) {
        guard !multipleChoiceResponses.isEmpty else { return }
        
        let db = Firestore.firestore()
        let batch = db.batch()
        
        for response in multipleChoiceResponses {
            do {
                let data = try JSONEncoder().encode(response)
                var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                
                // Convert timestamp to Firestore Timestamp
                dict["timestamp"] = Timestamp(date: response.timestamp)
                dict["userId"] = userId
                
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
        batch.commit { [self] error in
            if let error = error {
                print("Error saving multiple choice responses: \(error.localizedDescription)")
            } else {
                print("Successfully saved \(self.multipleChoiceResponses.count) multiple choice responses")
            }
        }
    }
}