import FirebaseFirestore
import SwiftUI

struct QuestionsView: View {
    let articleId: String
    @StateObject private var viewModel = ArticleViewModel()
    @State private var isLoading = true
    @State private var selectedAnswers: [String: String] = [:] // questionText -> selected choice
    @State private var showSubmitButton = false

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading questions...")
            } else if viewModel.openEndedQuestions.isEmpty && viewModel.multipleChoiceQuestions.isEmpty {
                Text("No questions found for this article.")
                    .foregroundColor(.gray)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        if !viewModel.multipleChoiceQuestions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Multiple Choice Questions")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(viewModel.multipleChoiceQuestions) { question in
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text(question.questionText)
                                            .font(.headline)
                                            .padding(.horizontal)

                                        VStack(spacing: 8) {
                                            ForEach(question.choices, id: \.self) { choice in
                                                Button(action: {
                                                    selectedAnswers[question.questionText] = choice
                                                    showSubmitButton = true
                                                }) {
                                                    HStack {
                                                        Text(choice)
                                                            .foregroundColor(.primary)
                                                            .multilineTextAlignment(.leading)
                                                        Spacer()
                                                        if selectedAnswers[question.questionText] == choice {
                                                            Image(systemName: "checkmark.circle.fill")
                                                                .foregroundColor(.blue)
                                                        }
                                                    }
                                                    .padding()
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(selectedAnswers[question.questionText] == choice ?
                                                                Color.blue.opacity(0.1) : Color(.systemGray6))
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 8)
                                                                    .stroke(selectedAnswers[question.questionText] == choice ?
                                                                        Color.blue : Color.clear, lineWidth: 2)
                                                            )
                                                    )
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                    .padding(.vertical, 8)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                    .padding(.horizontal)
                                }
                            }
                        }

                        if !viewModel.openEndedQuestions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Open-Ended Questions")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(viewModel.openEndedQuestions) { question in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(question.questionText)
                                            .font(.headline)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .padding(.horizontal)
                                }
                            }
                        }

                        if showSubmitButton {
                            Button(action: {
                                // TODO: Handle submit action
                                print("Selected answers: \(selectedAnswers)")
                            }) {
                                Text("Submit Answers")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                        }
                    }
                    .padding(.vertical)
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
