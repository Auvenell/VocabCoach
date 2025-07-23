import SwiftUI
import FirebaseFirestore

struct QuestionsView: View {
    let articleId: String
    init(articleId: String) {
        self.articleId = articleId
    }
    @State private var questions: [ComprehensionQuestion] = []
    @State private var isLoading = true
    private var db = Firestore.firestore()

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading questions...")
            } else if questions.isEmpty {
                Text("No questions found for this article.")
                    .foregroundColor(.gray)
            } else {
                List(questions) { question in
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
        .navigationTitle("Questions")
        .onAppear {
            fetchQuestions()
        }
    }

    private func fetchQuestions() {
        db.collection("comprehension_questions")
            .whereField("articleId", isEqualTo: articleId)
            .getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    self.questions = documents.compactMap { doc in
                        let data = doc.data()
                        return ComprehensionQuestion(
                            id: doc.documentID,
                            articleId: (data["articleId"] as? String) ?? "",
                            questionText: data["questionText"] as? String ?? "",
                            answer: data["answer"] as? String ?? ""
                        )
                    }
                }
                self.isLoading = false
            }
    }
}
