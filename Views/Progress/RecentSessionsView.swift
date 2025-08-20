import SwiftUI

// MARK: - Recent Sessions View
struct RecentSessionsView: View {
    let sessions: [CombinedQuestionSession]
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Sessions")
                .font(.headline)
                .fontWeight(.semibold)
            
            if isLoading {
                ProgressView("Loading recent sessions...")
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            } else if sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No recent sessions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(sessions, id: \.sessionId) { session in
                        NavigationLink(destination: SessionResultsView(sessionId: session.sessionId, cameFromQuiz: false)) {
                            RecentSessionCard(session: session)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Recent Session Card
struct RecentSessionCard: View {
    let session: CombinedQuestionSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.articleTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    
                    Text(formatDate(session.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Accuracy indicator
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(session.accuracy * 100))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(accuracyColor)
                    
                    Text("Accuracy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Session details
            HStack(spacing: 16) {
                SessionDetailItem(
                    title: "Points",
                    value: "\(session.earnedPoints)/\(session.totalPoints)",
                    icon: "star.fill",
                    color: .orange
                )
                
                SessionDetailItem(
                    title: "Time",
                    value: formatTime(session.totalTimeSpent),
                    icon: "clock.fill",
                    color: .blue
                )
                
                SessionDetailItem(
                    title: "Questions",
                    value: "\(getTotalQuestions(session))",
                    icon: "questionmark.circle.fill",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var accuracyColor: Color {
        if session.accuracy >= 0.8 {
            return .green
        } else if session.accuracy >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    private func getTotalQuestions(_ session: CombinedQuestionSession) -> Int {
        var total = 0
        if let mc = session.multipleChoiceSession {
            total += mc.totalQuestions
        }
        if let oe = session.openEndedSession {
            total += oe.totalQuestions
        }
        if let vocab = session.vocabularySession {
            total += vocab.totalQuestions
        }
        return total
    }
}

// MARK: - Session Detail Item
struct SessionDetailItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    RecentSessionsView(
        sessions: [],
        isLoading: false
    )
}
