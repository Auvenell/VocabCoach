import Foundation
import NaturalLanguage

struct PracticeParagraph: Identifiable {
    let id: String
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
    let isProperNoun: Bool
}

// Word classification helper for completion summary
enum WordClassifier {
    static let importantWordTypes: Set<NLTag> = [
        .noun, .verb, .adjective, .adverb, .otherWord,
    ]

    static func isImportantWord(_ word: String) -> Bool {
        // Remove punctuation for classification
        let cleanWord = word.trimmingCharacters(in: .punctuationCharacters).lowercased()
        // Exception for articles 'a' and 'an', function words 'is' and 'for', and pronouns 'i', 'my', 'we'
        if ["a", "an", "is", "for", "i", "my", "we"].contains(cleanWord) {
            return false
        }
        // If the word is just punctuation, it's not important
        if cleanWord.isEmpty {
            return false
        }
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = cleanWord
        var result = false
        var foundTag: NLTag? = nil
        tagger.enumerateTags(in: cleanWord.startIndex ..< cleanWord.endIndex, unit: .word, scheme: .lexicalClass) { tag, _ in
            foundTag = tag
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
        totalWords = paragraph.words.count
        initializeWordAnalyses()
    }

    private mutating func initializeWordAnalyses() {
        wordAnalyses = paragraph.words.enumerated().map { index, word in
            let isImportant = WordClassifier.isImportantWord(word)
            let isProperNoun = WordMatcher.shared.isProperNoun(word)

            return WordAnalysis(
                word: word,
                expectedIndex: index,
                isCorrect: false,
                userSpoken: nil,
                isMissing: false,
                isMispronounced: false,
                isCurrentWord: index == 0,
                isImportantWord: isImportant,
                isProperNoun: isProperNoun
            )
        }
    }

    // Use the shared WordMatcher for word matching
    private func isWordMatch(expected: String, spoken: String) -> Bool {
        return WordMatcher.shared.isWordMatch(expected: expected, spoken: spoken)
    }

    mutating func analyzeTranscription(_ transcription: String) -> Bool {
        let spokenWords = transcription.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }

        // Only analyze the current word
        guard currentWordIndex < paragraph.words.count else { return false }

        let expectedWordRaw = paragraph.words[currentWordIndex]
        let expectedWord = expectedWordRaw.lowercased().trimmingCharacters(in: .punctuationCharacters)

        // Debug logging

        // Use the new comprehensive word matching system
        let userSpoken = spokenWords.first { spokenWord in
            isWordMatch(expected: expectedWordRaw, spoken: spokenWord)
        }

        // If no match found, check for compound word match
        let compoundWordMatch = userSpoken == nil && spokenWords.count >= 2 ?
            WordMatcher.shared.isCompoundWordMatch(expected: expectedWordRaw, lastTwoSpoken: spokenWords) : false

        let isCorrect = userSpoken != nil || compoundWordMatch
        let isMissing = spokenWords.isEmpty || (!spokenWords.contains { isWordMatch(expected: expectedWordRaw, spoken: $0) } && !compoundWordMatch)
        let isMispronounced = !isMissing && !isCorrect

        // Update the current word analysis
        if currentWordIndex < wordAnalyses.count {
            let currentWord = paragraph.words[currentWordIndex]
            let isImportant = WordClassifier.isImportantWord(currentWord)
            let isProperNoun = WordMatcher.shared.isProperNoun(currentWord)

            wordAnalyses[currentWordIndex] = WordAnalysis(
                word: currentWord,
                expectedIndex: currentWordIndex,
                isCorrect: isCorrect,
                userSpoken: userSpoken,
                isMissing: isMissing,
                isMispronounced: isMispronounced,
                isCurrentWord: true,
                isImportantWord: isImportant,
                isProperNoun: isProperNoun
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
                isImportantWord: currentAnalysis.isImportantWord,
                isProperNoun: currentAnalysis.isProperNoun
            )
        }

        // Move to next word
        currentWordIndex += 1

        // Haptic feedback for advancing to next word
        DispatchQueue.main.async {
            HapticManager.shared.mediumImpact()
        }

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
                isImportantWord: nextAnalysis.isImportantWord,
                isProperNoun: nextAnalysis.isProperNoun
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
        for i in (0 ..< searchIndex).reversed() {
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
        for i in sentenceStart ..< wordAnalyses.count {
            let word = paragraph.words[i]
            wordAnalyses[i] = WordAnalysis(
                word: word,
                expectedIndex: i,
                isCorrect: false,
                userSpoken: nil,
                isMissing: false,
                isMispronounced: false,
                isCurrentWord: i == sentenceStart,
                isImportantWord: WordClassifier.isImportantWord(word),
                isProperNoun: WordMatcher.shared.isProperNoun(word)
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

    // Public method to skip the current word
    mutating func skipCurrentWord() {
        advanceToNextWord()
    }
}
