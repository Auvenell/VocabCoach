import SwiftUI

struct QuestionResultsView: View {
    let totalPointsEarned: Int
    let totalPossiblePoints: Int
    let multipleChoiceCorrect: Int
    let multipleChoiceTotal: Int
    let openEndedCorrect: Int
    let openEndedTotal: Int
    let openEndedScores: [Double]
    let vocabularyCorrect: Int
    let vocabularyTotal: Int
    let sessionId: String
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
                        color: .blue,
                        scores: nil
                    )
                    
                    ResultRow(
                        title: "Open-Ended",
                        correct: openEndedScores.filter { $0 > 0.6 }.count,
                        total: openEndedTotal,
                        pointsPerQuestion: 10,
                        color: .green,
                        scores: openEndedScores
                    )
                    
                    ResultRow(
                        title: "Vocabulary",
                        correct: vocabularyCorrect,
                        total: vocabularyTotal,
                        pointsPerQuestion: 2,
                        color: .orange,
                        scores: nil
                    )
                }
                
                Spacer()
                
                // Continue Button
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
    let scores: [Double]? // Optional array of scores for open-ended questions
    
    private var pointsEarned: Int {
        if let scores = scores {
            // For open-ended questions, use the sum of scores
            return Int(scores.reduce(0, +) * Double(pointsPerQuestion))
        } else {
            // For multiple choice and vocabulary, use simple multiplication
            return correct * pointsPerQuestion
        }
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
