import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct SessionResultsView: View {
    let sessionId: String
    let cameFromQuiz: Bool // Controls both back button visibility and bottom button
    @StateObject private var progressManager = UserProgressManager()
    @State private var multipleChoiceResponses: [MultipleChoiceQuestionResponse] = []
    @State private var openEndedResponses: [OpenEndedQuestionResponse] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @EnvironmentObject var headerState: HeaderState
    @Environment(\.dismiss) private var dismiss
    
    // Default initializer - not from quiz by default
    init(sessionId: String, cameFromQuiz: Bool = false) {
        self.sessionId = sessionId
        self.cameFromQuiz = cameFromQuiz
    }
    
    var body: some View {
        Group {
            if cameFromQuiz {
                // When coming from quiz, don't wrap in NavigationView to avoid nested navigation
                ScrollView {
                    VStack(spacing: 20) {
                        if isLoading {
                            ProgressView("Loading session results...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if let error = errorMessage {
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                Text("Error loading results")
                                    .font(.headline)
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            // Session Summary
                            SessionSummaryView(
                                multipleChoiceCount: multipleChoiceResponses.count,
                                openEndedCount: openEndedResponses.count,
                                multipleChoiceCorrect: multipleChoiceResponses.filter { $0.isCorrect }.count,
                                openEndedCorrect: openEndedResponses.filter { $0.isCorrect }.count
                            )
                            
                            // Multiple Choice Results
                            if !multipleChoiceResponses.isEmpty {
                                MultipleChoiceResultsView(responses: multipleChoiceResponses)
                            }
                            
                            // Open Ended Results
                            if !openEndedResponses.isEmpty {
                                OpenEndedResultsView(responses: openEndedResponses)
                            }
                            
                            // Back to Welcome button (only show when coming from quiz)
                            VStack(spacing: 16) {
                                Divider()
                                    .padding(.vertical)
                                
                                NavigationLink(destination: ReadingPracticeView()) {
                                    HStack {
                                        Image(systemName: "house.fill")
                                        Text("Go Home")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Session Results")
                .navigationBarTitleDisplayMode(.large)
                .navigationBarBackButtonHidden(true)
                .onAppear {
                    setupHeader()
                    loadSessionResults()
                }
            } else {
                // When NOT coming from quiz, use NavigationView for standalone presentation
                NavigationView {
                    ScrollView {
                        VStack(spacing: 20) {
                            if isLoading {
                                ProgressView("Loading session results...")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else if let error = errorMessage {
                                VStack(spacing: 16) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.largeTitle)
                                        .foregroundColor(.orange)
                                    Text("Error loading results")
                                        .font(.headline)
                                    Text(error)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                // Session Summary
                                SessionSummaryView(
                                    multipleChoiceCount: multipleChoiceResponses.count,
                                    openEndedCount: openEndedResponses.count,
                                    multipleChoiceCorrect: multipleChoiceResponses.filter { $0.isCorrect }.count,
                                    openEndedCorrect: openEndedResponses.filter { $0.isCorrect }.count
                                )
                                
                                // Multiple Choice Results
                                if !multipleChoiceResponses.isEmpty {
                                    MultipleChoiceResultsView(responses: multipleChoiceResponses)
                                }
                                
                                // Open Ended Results
                                if !openEndedResponses.isEmpty {
                                    OpenEndedResultsView(responses: openEndedResponses)
                                }
                            }
                        }
                        .padding()
                    }
                    .navigationTitle("Session Results")
                    .navigationBarTitleDisplayMode(.large)
                    .onAppear {
                        setupHeader()
                        loadSessionResults()
                    }
                }
            }
        }
    }
    
    private func setupHeader() {
        headerState.backButtonAction = nil // Removed onBack
        headerState.title = "Session Results"
        headerState.titleIcon = "doc.text.fill"
        headerState.titleColor = .blue
    }
    
    private func loadSessionResults() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        
        // Load multiple choice responses
        db.collection("question_sessions")
            .document(sessionId)
            .collection("multiple_choice_responses")
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = "Failed to load multiple choice responses: \(error.localizedDescription)"
                        self.isLoading = false
                        return
                    }
                    
                    self.multipleChoiceResponses = snapshot?.documents.compactMap { document in
                        try? document.data(as: MultipleChoiceQuestionResponse.self)
                    }.sorted { $0.questionNumber < $1.questionNumber } ?? []
                    
                    // Load open ended responses
                    db.collection("question_sessions")
                        .document(sessionId)
                        .collection("open_ended_responses")
                        .getDocuments { snapshot, error in
                            DispatchQueue.main.async {
                                if let error = error {
                                    self.errorMessage = "Failed to load open ended responses: \(error.localizedDescription)"
                                    self.isLoading = false
                                    return
                                }
                                
                                self.openEndedResponses = snapshot?.documents.compactMap { document in
                                    try? document.data(as: OpenEndedQuestionResponse.self)
                                }.sorted { $0.questionNumber < $1.questionNumber } ?? []
                                
                                self.isLoading = false
                            }
                        }
                }
            }
    }
}

// MARK: - Supporting Views

struct SessionSummaryView: View {
    let multipleChoiceCount: Int
    let openEndedCount: Int
    let multipleChoiceCorrect: Int
    let openEndedCorrect: Int
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Session Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                // Multiple Choice Summary
                VStack(spacing: 8) {
                    Text("Multiple Choice")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Text("\(multipleChoiceCorrect)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("/")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("\(multipleChoiceCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Open Ended Summary
                VStack(spacing: 8) {
                    Text("Open Ended")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Text("\(openEndedCorrect)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("/")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("\(openEndedCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct MultipleChoiceResultsView: View {
    let responses: [MultipleChoiceQuestionResponse]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Multiple Choice Questions")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 12) {
                ForEach(responses, id: \.questionNumber) { response in
                    MultipleChoiceResultCard(response: response)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct MultipleChoiceResultCard: View {
    let response: MultipleChoiceQuestionResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Question \(response.questionNumber)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Correct/Incorrect indicator
                HStack(spacing: 4) {
                    Image(systemName: response.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(response.isCorrect ? .green : .red)
                    Text(response.isCorrect ? "Correct" : "Incorrect")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(response.isCorrect ? .green : .red)
                }
            }
            
            Text(response.questionText)
                .font(.body)
                .fontWeight(.medium)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Answer:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(response.studentAnswer.count > 1 ? response.studentAnswer[1] : response.studentAnswer.first ?? "")
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            if !response.isCorrect {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Correct Answer:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(response.correctAnswer.count > 1 ? response.correctAnswer[1] : response.correctAnswer.first ?? "")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct OpenEndedResultsView: View {
    let responses: [OpenEndedQuestionResponse]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Open Ended Questions")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 16) {
                ForEach(responses, id: \.questionNumber) { response in
                    OpenEndedResultCard(response: response)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct OpenEndedResultCard: View {
    let response: OpenEndedQuestionResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Question \(response.questionNumber)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Score indicator
                HStack(spacing: 4) {
                    Text("Score: \(Int(response.score * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(scoreColor)
                }
            }
            
            Text(response.questionText)
                .font(.body)
                .fontWeight(.medium)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Answer:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(response.studentAnswer)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Feedback:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(response.llmFeedback)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Reasoning:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(response.llmReason)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var scoreColor: Color {
        if response.score >= 0.8 {
            return .green
        } else if response.score >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

#Preview {
    SessionResultsView(sessionId: "preview-session-id", cameFromQuiz: false)
}
