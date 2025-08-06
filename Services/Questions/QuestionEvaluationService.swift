//
//  QuestionEvaluationService.swift
//  VocabCoach
//
//  Created by Aunik Paul on 8/6/25.
//

import Foundation

// MARK: - Question Evaluation Service

class QuestionEvaluationService: ObservableObject {
    private let llmService = LLMEvaluationService()
    
    // Async function to evaluate with LLM
    func evaluateWithLLM(
        _ article: String,
        _ questionText: String,
        _ expectedAnswer: String,
        _ studentAnswer: String,
        _ questionNumber: Int,
        sessionManager: QuestionSessionManager
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
            sessionManager.openEndedResponses.append(response)
            
            // Track the score for session calculation
            sessionManager.trackOpenEndedAnswer(score: evaluation.score)
        }
        
        // Return the calculated isCorrect value based on score threshold
        if let evaluation = evaluation {
            return evaluation.score > 0.6
        }
        return false
    }
    
    // Simple evaluation for open-ended answers (fallback)
    func evaluateOpenEndedAnswer(_ userAnswer: String, _ expectedAnswer: String) -> Bool {
        let cleanUserAnswer = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanExpectedAnswer = expectedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Simple keyword matching - check if user answer contains key words from expected answer
        let expectedWords = cleanExpectedAnswer.components(separatedBy: .whitespaces)
            .filter { $0.count > 3 } // Only consider words longer than 3 characters
        
        let userWords = Set(cleanUserAnswer.components(separatedBy: .whitespaces))
        
        let matchingWords = expectedWords.filter { userWords.contains($0) }
        
        // Consider correct if at least 60% of important words match
        let matchPercentage = Double(matchingWords.count) / Double(expectedWords.count)
        return matchPercentage >= 0.6
    }
    
    // Check if all questions are completed
    func allQuestionsCompleted(
        multipleChoiceQuestions: [MultipleChoiceQuestion],
        openEndedQuestions: [ComprehensionQuestion],
        vocabularyWords: [String],
        selectedAnswers: [String: String],
        openEndedAnswers: [String: String],
        vocabularyAnswers: [String: String]
    ) -> Bool {
        let multipleChoiceCompleted = multipleChoiceQuestions.allSatisfy { question in
            selectedAnswers[question.questionText] != nil
        }
        
        let openEndedCompleted = openEndedQuestions.allSatisfy { question in
            !(openEndedAnswers[question.questionText] ?? "").isEmpty
        }
        
        let vocabularyCompleted = vocabularyWords.allSatisfy { word in
            !(vocabularyAnswers[word] ?? "").isEmpty
        }
        
        return multipleChoiceCompleted && openEndedCompleted && vocabularyCompleted
    }
    
    // Calculate total points earned
    func calculateTotalPointsEarned(
        multipleChoiceCorrect: Int,
        openEndedScores: [Double],
        vocabularyCorrect: Int
    ) -> Int {
        let multipleChoicePoints = multipleChoiceCorrect * 8
        let openEndedPoints = Int(openEndedScores.reduce(0, +) * 10) // Sum of scores * 10 points per question
        let vocabularyPoints = vocabularyCorrect * 2
        return multipleChoicePoints + openEndedPoints + vocabularyPoints
    }
    
    // Calculate total possible points
    func calculateTotalPossiblePoints(
        multipleChoiceCount: Int,
        openEndedCount: Int,
        vocabularyCount: Int
    ) -> Int {
        let multipleChoiceTotal = multipleChoiceCount * 8
        let openEndedTotal = openEndedCount * 10
        let vocabularyTotal = vocabularyCount * 2
        return multipleChoiceTotal + openEndedTotal + vocabularyTotal
    }
}