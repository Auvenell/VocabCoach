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
    let studentAnswer: [String] // [choice_identifier, choice_text] e.g. ["choice_a", "First option"]
    let correctAnswer: [String] // [choice_identifier, choice_text] e.g. ["choice_a", "First option"]
    let isCorrect: Bool
    let timestamp: Date
}