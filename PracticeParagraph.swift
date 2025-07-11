import Foundation

struct PracticeParagraph: Identifiable {
    let id = UUID()
    let title: String
    let text: String
    let difficulty: Difficulty
    let category: Category
    
    enum Difficulty: String, CaseIterable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
    }
    
    enum Category: String, CaseIterable {
        case general = "General"
        case business = "Business"
        case academic = "Academic"
        case casual = "Casual"
    }
    
    var words: [String] {
        return text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
    }
}

struct WordAnalysis {
    let word: String
    let expectedIndex: Int
    let isCorrect: Bool
    let confidence: Float
    let userSpoken: String?
    let isMissing: Bool
    let isMispronounced: Bool
}

struct ReadingSession {
    let paragraph: PracticeParagraph
    var wordAnalyses: [WordAnalysis] = []
    var startTime: Date?
    var endTime: Date?
    var totalWords: Int
    var correctWords: Int = 0
    var accuracy: Double {
        guard totalWords > 0 else { return 0.0 }
        return Double(correctWords) / Double(totalWords)
    }
    
    init(paragraph: PracticeParagraph) {
        self.paragraph = paragraph
        self.totalWords = paragraph.words.count
    }
    
    mutating func analyzeTranscription(_ transcription: String, confidence: Float) {
        let spokenWords = transcription.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
        
        let expectedWords = paragraph.words.map { $0.lowercased() }
        
        wordAnalyses.removeAll()
        correctWords = 0
        
        for (index, expectedWord) in expectedWords.enumerated() {
            let isMissing = index >= spokenWords.count
            let userSpoken = isMissing ? nil : spokenWords[index]
            let isCorrect = !isMissing && userSpoken == expectedWord
            let isMispronounced = !isMissing && !isCorrect && userSpoken != nil
            
            if isCorrect {
                correctWords += 1
            }
            
            let analysis = WordAnalysis(
                word: paragraph.words[index],
                expectedIndex: index,
                isCorrect: isCorrect,
                confidence: confidence,
                userSpoken: userSpoken,
                isMissing: isMissing,
                isMispronounced: isMispronounced
            )
            
            wordAnalyses.append(analysis)
        }
    }
} 