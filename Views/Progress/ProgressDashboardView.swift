import SwiftUI
import Charts
import FirebaseAuth

struct ProgressDashboardView: View {
    // MARK: - Properties
    @StateObject private var progressManager = UserProgressManager()
    @State private var recentSessions: [CombinedQuestionSession] = []
    @State private var isLoadingSessions = false
    @EnvironmentObject var headerState: HeaderState
    var onBack: (() -> Void)?
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Recent Sessions Section
                    RecentSessionsView(
                        sessions: recentSessions,
                        isLoading: isLoadingSessions
                    )
                }
                .padding()
            }
            .navigationTitle("Progress Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                setupHeader()
                loadRecentSessions()
            }
        }
    }
    
    // MARK: - Helper Methods
    private func setupHeader() {
        headerState.showBackButton = true
        headerState.backButtonAction = onBack
        headerState.title = "Progress"
        headerState.titleIcon = "chart.bar.fill"
        headerState.titleColor = .blue
    }
    
    private func loadRecentSessions() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoadingSessions = true
        progressManager.getRecentQuestionSessions(userId: userId, limit: 3) { sessions in
            DispatchQueue.main.async {
                self.recentSessions = sessions
                self.isLoadingSessions = false
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ProgressDashboardView()
} 