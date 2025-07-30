import FirebaseFirestore
import Foundation

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

struct MultipleChoiceQuestion: Identifiable {
    var id: String { questionText } // Use questionText as unique id for now
    var questionText: String
    var choices: [String]
    var answer: String
}

class ArticleViewModel: ObservableObject {
    @Published var articles: [Article] = []
    @Published var openEndedQuestions: [ComprehensionQuestion] = []
    @Published var multipleChoiceQuestions: [MultipleChoiceQuestion] = []

    private var db = Firestore.firestore()

    func fetchArticles() {
        db.collection("articles").getDocuments { snapshot, _ in
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
        db.collection("articles").document(articleId).getDocument { snapshot, _ in
            guard let data = snapshot?.data() else { return }
            // Open-ended questions
            if let questionsArray = data["questions"] as? [[String: Any]] {
                self.openEndedQuestions = questionsArray.compactMap { dict in
                    guard let questionText = dict["questionText"] as? String,
                          let answer = dict["answer"] as? String else { return nil }
                    return ComprehensionQuestion(
                        id: UUID().uuidString,
                        articleId: articleId,
                        questionText: questionText,
                        answer: answer
                    )
                }
            } else {
                self.openEndedQuestions = []
            }
            // Multiple choice questions
            if let mcqArray = data["multiple_choice_questions"] as? [[String: Any]] {
                self.multipleChoiceQuestions = mcqArray.compactMap { dict in
                    guard let questionText = dict["questionText"] as? String,
                          let answer = dict["answer"] as? String else { return nil }
                    let choices = [dict["choice_a"], dict["choice_b"], dict["choice_c"], dict["choice_d"]].compactMap { $0 as? String }
                    return MultipleChoiceQuestion(
                        questionText: questionText,
                        choices: choices,
                        answer: answer
                    )
                }
            } else {
                self.multipleChoiceQuestions = []
            }
        }
    }
}
