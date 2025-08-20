//
//  OpenEndedQuestionView.swift
//  VocabCoach
//
//  Created by Aunik Paul on 8/6/25.
//

import SwiftUI

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
        VStack(alignment: .leading, spacing: 16) {
            // Question Header
            HStack(alignment: .top, spacing: 16) {
                Text("\(questionNumber)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                
                Text(question.questionText)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
            
            // Answer Section using shared component
            AnswerSectionView(
                label: "Your Answer:",
                placeholder: "Start recording or type your answer...",
                editingAnswer: editingAnswer,
                isLocked: isLocked,
                isRecording: isRecording,
                transcribedText: transcribedText,
                onStartRecording: onStartRecording,
                onStopRecording: onStopRecording,
                onAnswerChanged: onAnswerChanged,
                onLockAnswer: onLockAnswer,
                onUnlockAnswer: onUnlockAnswer
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isLocked ? Color.green.opacity(0.4) : Color.clear,
                    lineWidth: isLocked ? 3 : 0
                )
        )
        .scaleEffect(isLocked ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isLocked)
    }
}