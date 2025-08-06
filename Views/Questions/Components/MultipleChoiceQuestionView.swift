//
//  MultipleChoiceQuestionView.swift
//  VocabCoach
//
//  Created by Aunik Paul on 8/6/25.
//

import SwiftUI

struct MultipleChoiceQuestionView: View {
    let question: MultipleChoiceQuestion
    let questionNumber: Int
    let selectedAnswer: String?
    let isSectionCompleted: Bool
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
            
            // Show completion message if section is completed
            if isSectionCompleted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Multiple choice section completed - answers locked")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
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
                                    .foregroundColor(isSectionCompleted ? .secondary : .primary)
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
                        .disabled(isSectionCompleted)
                    }
                }
            }
        }
    }
}