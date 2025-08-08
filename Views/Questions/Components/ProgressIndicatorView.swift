import SwiftUI

struct ProgressIndicatorView: View {
    let currentSection: Int
    let totalSections: Int
    let currentQuestion: Int
    let totalQuestions: Int
    
    var body: some View {
        VStack(spacing: 8) {
            // Section progress
            HStack {
                Text("Section \(currentSection + 1) of \(totalSections)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Question \(currentQuestion) of \(totalQuestions)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * CGFloat(currentQuestion) / CGFloat(totalQuestions), height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}
