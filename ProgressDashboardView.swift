import SwiftUI
import Charts
import FirebaseAuth

struct ProgressDashboardView: View {
    @StateObject private var progressManager = UserProgressManager()
    @State private var weeklyStats: [UserAnalytics.DailyStats] = []
    @State private var wordProgress: [WordProgress] = []
    @State private var selectedTimeframe: Timeframe = .week
    @State private var isLoading = false
    @EnvironmentObject var headerState: HeaderState
    var onBack: (() -> Void)?
    
    enum Timeframe: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let progress = progressManager.currentProgress {
                        // Header with user level and streak
                        UserProgressHeader(progress: progress)
                        
                        // Timeframe selector
                        TimeframeSelector(selectedTimeframe: $selectedTimeframe)
                        
                        // Weekly progress chart
                        WeeklyProgressChart(stats: weeklyStats)
                        
                        // Key metrics
                        KeyMetricsView(progress: progress)
                        
                        // Word mastery progress
                        WordMasteryView(wordProgress: wordProgress)
                        
                        // Recent activity
                        RecentActivityView()
                    } else if progressManager.isLoading {
                        ProgressView("Loading your progress...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Text("No progress data available")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding()
            }
            .navigationTitle("Progress Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Set up header for progress dashboard
                headerState.showBackButton = true
                headerState.backButtonAction = onBack
                headerState.title = "Progress"
                headerState.titleIcon = "chart.bar.fill"
                headerState.titleColor = .blue
            }
            .refreshable {
                await loadProgressData()
            }
            .onAppear {
                Task {
                    await loadProgressData()
                }
            }
        }
    }
    
    private func loadProgressData() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        // Load weekly stats
        progressManager.getWeeklyProgress(userId: userId) { stats in
            DispatchQueue.main.async {
                self.weeklyStats = stats
                self.isLoading = false
            }
        }
        
        // Load word progress
        progressManager.getWordMasteryProgress(userId: userId) { wordProgress in
            DispatchQueue.main.async {
                self.wordProgress = wordProgress
            }
        }
    }
}

// MARK: - Supporting Views

struct UserProgressHeader: View {
    let progress: UserProgress
    
    var body: some View {
        VStack(spacing: 16) {
            // Level badge
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Level")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(progress.level.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(levelColor(for: progress.level))
                }
                
                Spacer()
                
                // Streak
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(progress.streakDays) days")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
            }
            
            // Progress bar to next level
            LevelProgressBar(currentLevel: progress.level, accuracy: progress.averageAccuracy)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func levelColor(for level: UserProgress.UserLevel) -> Color {
        switch level {
        case .beginner:
            return .green
        case .intermediate:
            return .blue
        case .advanced:
            return .orange
        case .expert:
            return .red
        }
    }
}

struct LevelProgressBar: View {
    let currentLevel: UserProgress.UserLevel
    let accuracy: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progress to next level")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(accuracy * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(progressColor)
                        .frame(width: geometry.size.width * progressPercentage, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
    
    private var progressColor: Color {
        switch currentLevel {
        case .beginner:
            return .green
        case .intermediate:
            return .blue
        case .advanced:
            return .orange
        case .expert:
            return .red
        }
    }
    
    private var progressPercentage: Double {
        let nextLevel = getNextLevel()
        let currentRequired = currentLevel.requiredAccuracy
        let nextRequired = nextLevel.requiredAccuracy
        let progress = (accuracy - currentRequired) / (nextRequired - currentRequired)
        return max(0, min(1, progress))
    }
    
    private func getNextLevel() -> UserProgress.UserLevel {
        switch currentLevel {
        case .beginner:
            return .intermediate
        case .intermediate:
            return .advanced
        case .advanced:
            return .expert
        case .expert:
            return .expert
        }
    }
}

struct TimeframeSelector: View {
    @Binding var selectedTimeframe: ProgressDashboardView.Timeframe
    
    var body: some View {
        HStack {
            ForEach(ProgressDashboardView.Timeframe.allCases, id: \.self) { timeframe in
                Button(action: {
                    selectedTimeframe = timeframe
                }) {
                    Text(timeframe.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTimeframe == timeframe ? Color.blue : Color.clear)
                        )
                        .foregroundColor(selectedTimeframe == timeframe ? .white : .primary)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WeeklyProgressChart: View {
    let stats: [UserAnalytics.DailyStats]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Progress")
                .font(.headline)
                .fontWeight(.semibold)
            
            if stats.isEmpty {
                Text("No data available for this week")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            } else {
                Chart {
                    ForEach(stats, id: \.date) { stat in
                        LineMark(
                            x: .value("Date", stat.date),
                            y: .value("Accuracy", stat.accuracy * 100)
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        
                        AreaMark(
                            x: .value("Date", stat.date),
                            y: .value("Accuracy", stat.accuracy * 100)
                        )
                        .foregroundStyle(.blue.opacity(0.1))
                    }
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            Text("\(value.as(Double.self)?.formatted(.number.precision(.fractionLength(0))) ?? "")%")
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.weekday(.abbreviated))
                            }
                        }
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

struct KeyMetricsView: View {
    let progress: UserProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Metrics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MetricCard(
                    title: "Total Sessions",
                    value: "\(progress.totalSessions)",
                    icon: "book.fill",
                    color: .blue
                )
                
                MetricCard(
                    title: "Words Read",
                    value: "\(progress.totalWordsRead)",
                    icon: "textformat",
                    color: .green
                )
                
                MetricCard(
                    title: "Average Accuracy",
                    value: "\(Int(progress.averageAccuracy * 100))%",
                    icon: "target",
                    color: .orange
                )
                
                MetricCard(
                    title: "Time Spent",
                    value: formatTime(progress.totalTimeSpent),
                    icon: "clock.fill",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct WordMasteryView: View {
    let wordProgress: [WordProgress]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Word Mastery")
                .font(.headline)
                .fontWeight(.semibold)
            
            if wordProgress.isEmpty {
                Text("No word progress data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(wordProgress.prefix(5), id: \.word) { progress in
                        WordProgressRow(progress: progress)
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

struct WordProgressRow: View {
    let progress: WordProgress
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(progress.word)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(progress.masteryLevel.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(masteryColor)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int((Double(progress.correctAttempts) / Double(progress.totalAttempts)) * 100))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("\(progress.totalAttempts) attempts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var masteryColor: Color {
        switch progress.masteryLevel {
        case .new:
            return .red
        case .learning:
            return .orange
        case .needsReview:
            return .yellow
        case .mastered:
            return .green
        }
    }
}

struct RecentActivityView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Placeholder for recent activity
            Text("Recent activity will appear here")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, minHeight: 100)
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    ProgressDashboardView()
} 