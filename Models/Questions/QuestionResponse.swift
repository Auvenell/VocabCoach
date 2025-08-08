//
//  QuestionResponse.swift
//  VocabCoach
//
//  Created by Aunik Paul on 8/6/25.
//

import Foundation

// MARK: - Question Response Data Structures

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

struct MultipleChoiceQuestionResponse: Codable {
    let questionNumber: Int
    let questionText: String
    let studentAnswer: String // choice_a, choice_b, choice_c, choice_d
    let correctAnswer: String // choice_a, choice_b, choice_c, choice_d
    let isCorrect: Bool
    let timestamp: Date
}