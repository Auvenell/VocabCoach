import FirebaseFirestore
import Foundation

class ParagraphDataManager: ObservableObject {
    @Published var paragraphs: [PracticeParagraph] = []
    private var db = Firestore.firestore()

    init() {
        fetchParagraphsFromFirestore()
    }

    private func fetchParagraphsFromFirestore() {
        db.collection("articles").getDocuments { snapshot, _ in
            guard let documents = snapshot?.documents else { return }
            self.paragraphs = documents.compactMap { doc in
                let data = doc.data()
                guard let title = data["title"] as? String,
                      let text = data["content"] as? String,
                      let difficultyStr = data["difficulty"] as? String,
                      let categoryStr = data["category"] as? String
                else {
                    return nil
                }
                // Map Firestore strings to enums (case-insensitive)
                let difficulty = PracticeParagraph.Difficulty(rawValue: difficultyStr.capitalized) ?? .beginner
                let category = PracticeParagraph.Category(rawValue: categoryStr.capitalized) ?? .general
                return PracticeParagraph(
                    id: doc.documentID,
                    title: title,
                    text: text,
                    difficulty: difficulty,
                    category: category
                )
            }
        }
    }

    func getParagraphs(for difficulty: PracticeParagraph.Difficulty? = nil, category: PracticeParagraph.Category? = nil) -> [PracticeParagraph] {
        var filteredParagraphs = paragraphs

        if let difficulty = difficulty {
            filteredParagraphs = filteredParagraphs.filter { $0.difficulty == difficulty }
        }

        if let category = category {
            filteredParagraphs = filteredParagraphs.filter { $0.category == category }
        }

        return filteredParagraphs
    }

    func getRandomParagraph(difficulty: PracticeParagraph.Difficulty? = nil, category: PracticeParagraph.Category? = nil) -> PracticeParagraph? {
        let filteredParagraphs = getParagraphs(for: difficulty, category: category)
        return filteredParagraphs.randomElement()
    }
}
