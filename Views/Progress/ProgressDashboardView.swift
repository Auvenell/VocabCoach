import SwiftUI
import Charts
import FirebaseAuth

struct ProgressDashboardView: View {
    // MARK: - Properties
    @StateObject private var progressManager = UserProgressManager()
    @EnvironmentObject var headerState: HeaderState
    var onBack: (() -> Void)?
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // TODO: Add your progress dashboard content here
                    Text("Progress Dashboard - Empty Template")
                        .font(.title)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding()
            }
            .navigationTitle("Progress Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                setupHeader()
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
}

// MARK: - Preview
#Preview {
    ProgressDashboardView()
} 