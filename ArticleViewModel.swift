import Foundation
import FirebaseFirestore

struct Article: Identifiable {
    var id: String
    var title: String
    var content: String
    var difficulty: String
    var category: String
}

struct ComprehensionQuestion: Identifiable {
    var id: String
    var articleId: String // or DocumentReference if you used reference type
    var questionText: String
    var answer: String
}

class ArticleViewModel: ObservableObject {
    @Published var articles: [Article] = []
    @Published var questions: [ComprehensionQuestion] = []

    private var db = Firestore.firestore()

    func fetchArticles() {
        db.collection("articles").getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else { return }
            self.articles = documents.compactMap { doc in
                let data = doc.data()
                return Article(
                    id: doc.documentID,
                    title: data["title"] as? String ?? "",
                    content: data["content"] as? String ?? "",
                    difficulty: data["difficulty"] as? String ?? "",
                    category: data["category"] as? String ?? ""
                )
            }
        }
    }

    func fetchQuestions(for articleId: String) {
        db.collection("comprehension_questions")
            .whereField("articleId", isEqualTo: articleId)
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else { return }
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
    }
} 