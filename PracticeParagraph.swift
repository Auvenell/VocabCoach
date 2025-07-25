import Foundation
import NaturalLanguage

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
    }
}

struct WordAnalysis {
    let word: String
    let expectedIndex: Int
    let isCorrect: Bool
    let userSpoken: String?
    let isMissing: Bool
    let isMispronounced: Bool
    let isCurrentWord: Bool
    let isImportantWord: Bool
}

// Word classification helper for completion summary
struct WordClassifier {
    static let importantWordTypes: Set<NLTag> = [
        .noun, .verb, .adjective, .adverb, .otherWord
    ]
    
    static func isImportantWord(_ word: String) -> Bool {
        // Remove punctuation for classification
        let cleanWord = word.trimmingCharacters(in: .punctuationCharacters).lowercased()
        // Exception for articles 'a' and 'an', and function words 'is' and 'for'
        if ["a", "an", "is", "for"].contains(cleanWord) {
            return false
        }
        
        // If the word is just punctuation, it's not important
        if cleanWord.isEmpty {
            return false
        }
        
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = cleanWord
        
        var result = false
        tagger.enumerateTags(in: cleanWord.startIndex..<cleanWord.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            if let tag = tag {
                result = importantWordTypes.contains(tag)
            }
            return false // Stop after first word
        }
        
        return result
    }
}

struct ReadingSession {
    let paragraph: PracticeParagraph
    var wordAnalyses: [WordAnalysis] = []
    var startTime: Date?
    var endTime: Date?
    var totalWords: Int
    var correctWords: Int = 0
    var currentWordIndex: Int = 0
    var incorrectImportantWordsSet: Set<String> = [] // Track unique incorrect important words
    var incorrectImportantWordTimestamps: [String: Date] = [:] // Track when each word was added
    var currentWordAttempts: Int = 0 // Track attempts on current word
    var currentWordStartTime: Date? // Track when we started on current word
    var accuracy: Double {
        guard totalWords > 0 else { return 0.0 }
        return Double(correctWords) / Double(totalWords)
    }
    
    init(paragraph: PracticeParagraph) {
        self.paragraph = paragraph
        self.totalWords = paragraph.words.count
        self.initializeWordAnalyses()
    }
    
    private mutating func initializeWordAnalyses() {
        wordAnalyses = paragraph.words.enumerated().map { index, word in
            let isImportant = WordClassifier.isImportantWord(word)

            return WordAnalysis(
                word: word,
                expectedIndex: index,
                isCorrect: false,
                userSpoken: nil,
                isMissing: false,
                isMispronounced: false,
                isCurrentWord: index == 0,
                isImportantWord: isImportant
            )
        }
    }
    
    mutating func analyzeTranscription(_ transcription: String) -> Bool {
        let spokenWords = transcription.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
        
        // Only analyze the current word
        guard currentWordIndex < paragraph.words.count else { return false }
        
        let expectedWord = paragraph.words[currentWordIndex].lowercased().trimmingCharacters(in: .punctuationCharacters)
        
        // Check if the expected word appears anywhere in the spoken words
        // Use more flexible matching for unclear pronunciations
        let userSpoken = spokenWords.first { spokenWord in
            // Exact match
            if spokenWord == expectedWord {
                return true
            }
            
            return false
        }
        
        let isCorrect = userSpoken != nil
        let isMissing = spokenWords.isEmpty || !spokenWords.contains { $0 == expectedWord }
        let isMispronounced = !isMissing && !isCorrect
        
        // Update the current word analysis
        if currentWordIndex < wordAnalyses.count {
            let currentWord = paragraph.words[currentWordIndex]
            let isImportant = WordClassifier.isImportantWord(currentWord)
            
            wordAnalyses[currentWordIndex] = WordAnalysis(
                word: currentWord,
                expectedIndex: currentWordIndex,
                isCorrect: isCorrect,
                userSpoken: userSpoken,
                isMissing: isMissing,
                isMispronounced: isMispronounced,
                isCurrentWord: true,
                isImportantWord: isImportant
            )
        }
        
        let currentWord = paragraph.words[currentWordIndex]
        let isImportant = WordClassifier.isImportantWord(currentWord)
        let isFirstInSentence = isFirstWordOfSentence(currentWordIndex)
        
        // If the current word is correct, advance to the next word
        if isCorrect {
            // If this word was previously added to the practice list, check if it should be removed
            if isImportant, let addedTime = incorrectImportantWordTimestamps[currentWord] {
                let now = Date()
                let allowedTime: TimeInterval = isFirstInSentence ? 3.0 : 1.0
                if now.timeIntervalSince(addedTime) <= allowedTime {
                    // Remove from practice list and timestamp tracking
                    incorrectImportantWordsSet.remove(currentWord)
                    incorrectImportantWordTimestamps.removeValue(forKey: currentWord)
                }
            }
            correctWords += 1
            currentWordAttempts = 0 // Reset attempts
            currentWordStartTime = nil // Reset start time
            advanceToNextWord()
            return true // Indicate that the word was completed
        }
        
        // Track when we started on this word if this is the first attempt
        if currentWordAttempts == 0 {
            currentWordStartTime = Date()
        }
        
        // Increment attempts for current word
        currentWordAttempts += 1

        // Only add to practice list if user is genuinely stuck (multiple attempts or significant time)
        // This prevents adding words that are briefly misrecognized but then corrected
        if !isCorrect {
            // Consider user stuck if they've made multiple attempts OR spent significant time
            let timeSpent = currentWordStartTime != nil ? Date().timeIntervalSince(currentWordStartTime!) : 0.0
            let isStuck = currentWordAttempts >= 2 || timeSpent > 2.0 // 5 seconds
            if isImportant && isStuck {
                if !incorrectImportantWordsSet.contains(currentWord) {
                    incorrectImportantWordsSet.insert(currentWord)
                    incorrectImportantWordTimestamps[currentWord] = Date()
                }
            }
        }
        
        return false // Word not completed yet - stop for any incorrect word
    }
    
    private mutating func advanceToNextWord() {
        // Reset attempts for new word
        currentWordAttempts = 0
        currentWordStartTime = nil // Reset start time for new word
        
        // Mark current word as no longer current
        if currentWordIndex < wordAnalyses.count {
            let currentAnalysis = wordAnalyses[currentWordIndex]
            wordAnalyses[currentWordIndex] = WordAnalysis(
                word: currentAnalysis.word,
                expectedIndex: currentAnalysis.expectedIndex,
                isCorrect: currentAnalysis.isCorrect,
                userSpoken: currentAnalysis.userSpoken,
                isMissing: currentAnalysis.isMissing,
                isMispronounced: currentAnalysis.isMispronounced,
                isCurrentWord: false,
                isImportantWord: currentAnalysis.isImportantWord
            )
        }
        
        // Move to next word
        currentWordIndex += 1
        
        // Mark next word as current if we haven't finished
        if currentWordIndex < wordAnalyses.count {
            let nextAnalysis = wordAnalyses[currentWordIndex]
            wordAnalyses[currentWordIndex] = WordAnalysis(
                word: nextAnalysis.word,
                expectedIndex: nextAnalysis.expectedIndex,
                isCorrect: nextAnalysis.isCorrect,
                userSpoken: nextAnalysis.userSpoken,
                isMissing: nextAnalysis.isMissing,
                isMispronounced: nextAnalysis.isMispronounced,
                isCurrentWord: true,
                isImportantWord: nextAnalysis.isImportantWord
            )
        }
    }
    
    var isCompleted: Bool {
        return currentWordIndex >= totalWords
    }
    
    var currentWord: String? {
        guard currentWordIndex < paragraph.words.count else { return nil }
        return paragraph.words[currentWordIndex]
    }
    
    // Get list of important words that were ever pronounced incorrectly
    var wordsToReview: [String] {
        let reviewWords = Array(incorrectImportantWordsSet).sorted()
        return reviewWords
    }
    
    // Find the beginning of the current sentence
    func findSentenceStart() -> Int {
        // If completed, start from the last sentence
        let searchIndex = min(currentWordIndex, paragraph.words.count - 1)
        
        // Look backwards from current word to find the last sentence-ending punctuation
        for i in (0..<searchIndex).reversed() {
            let word = paragraph.words[i]
            // Check if this word ends with sentence-ending punctuation
            if word.hasSuffix(".") || word.hasSuffix("!") || word.hasSuffix("?") {
                return i + 1 // Return the word right after the punctuation
            }
        }
        
        // If no sentence end found, return beginning
        return 0
    }
    
    // Reset to beginning of current sentence
    mutating func resetToSentenceStart() {
        let sentenceStart = findSentenceStart()
        
        currentWordIndex = sentenceStart
        currentWordAttempts = 0 // Reset attempts for the new word
        
        // Reset word analyses for words from sentence start onwards
        for i in sentenceStart..<wordAnalyses.count {
            let word = paragraph.words[i]
            wordAnalyses[i] = WordAnalysis(
                word: word,
                expectedIndex: i,
                isCorrect: false,
                userSpoken: nil,
                isMissing: false,
                isMispronounced: false,
                isCurrentWord: i == sentenceStart,
                isImportantWord: WordClassifier.isImportantWord(word)
            )
        }
        
        // Reset correct words count
        correctWords = wordAnalyses.prefix(sentenceStart).filter { $0.isCorrect }.count
    }
    
    // Helper to check if a word is the first word of a sentence
    func isFirstWordOfSentence(_ index: Int) -> Bool {
        if index == 0 { return true }
        let prevWord = paragraph.words[index - 1]
        return prevWord.hasSuffix(".") || prevWord.hasSuffix("!") || prevWord.hasSuffix("?")
    }
} 