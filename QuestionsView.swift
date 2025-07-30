import FirebaseFirestore
import SwiftUI

struct QuestionsView: View {
    let articleId: String
    @StateObject private var viewModel = ArticleViewModel()
    @State private var isLoading = true

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading questions...")
            } else if viewModel.openEndedQuestions.isEmpty && viewModel.multipleChoiceQuestions.isEmpty {
                Text("No questions found for this article.")
                    .foregroundColor(.gray)
            } else {
                List {
                    if !viewModel.openEndedQuestions.isEmpty {
                        Section(header: Text("Open-Ended Questions")) {
                            ForEach(viewModel.openEndedQuestions) { question in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(question.questionText)
                                        .font(.headline)
                                    Text("Answer: \(question.answer)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    if !viewModel.multipleChoiceQuestions.isEmpty {
                        Section(header: Text("Multiple Choice Questions")) {
                            ForEach(viewModel.multipleChoiceQuestions) { question in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(question.questionText)
                                        .font(.headline)
                                    ForEach(question.choices, id: \.self) { choice in
                                        HStack {
                                            Text(choice)
                                                .padding(6)
                                                .background(choice == question.answer ? Color.green.opacity(0.2) : Color.clear)
                                                .cornerRadius(6)
                                            if choice == question.answer {
                                                Text("(Correct)")
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Questions")
        .onAppear {
            viewModel.fetchQuestions(for: articleId)
            // Add a slight delay to show loading spinner
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isLoading = false
            }
        }
    }
}
