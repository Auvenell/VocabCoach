//
//  QuestionSection.swift
//  VocabCoach
//
//  Created by Aunik Paul on 8/6/25.
//

import Foundation
import SwiftUI

// MARK: - Question Section Types

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