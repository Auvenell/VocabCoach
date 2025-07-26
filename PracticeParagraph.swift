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
}

// Word classification helper for completion summary
struct WordClassifier {
    static let importantWordTypes: Set<NLTag> = [
        .noun, .verb, .adjective, .adverb, .otherWord
    ]
    
    static func isImportantWord(_ word: String) -> Bool {
        // Remove punctuation for classification
        let cleanWord = word.trimmingCharacters(in: .punctuationCharacters).lowercased()
        // Exception for articles 'a' and 'an', function words 'is' and 'for', and pronouns 'i', 'my', 'we'
        if ["a", "an", "is", "for", "i", "my", "we"].contains(cleanWord) {
            print("[WordClassifier] '", word, "' (clean: '", cleanWord, "') is NOT important (article/function/pronoun word)")
            return false
        }
        // If the word is just punctuation, it's not important
        if cleanWord.isEmpty {
            print("[WordClassifier] '", word, "' (clean: '", cleanWord, "') is NOT important (empty after cleaning)")
            return false
        }
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = cleanWord
        var result = false
        var foundTag: NLTag? = nil
        tagger.enumerateTags(in: cleanWord.startIndex..<cleanWord.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            foundTag = tag
            if let tag = tag {
                result = importantWordTypes.contains(tag)
            }
            return false // Stop after first word
        }
        print("[WordClassifier] '", word, "' (clean: '", cleanWord, "') tag: ", String(describing: foundTag), " => important: ", result)
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
    
    // MARK: - Word Matching System
    
    /// Comprehensive word matching that handles homonyms, phonetic similarity, and common speech recognition errors
    private func isWordMatch(expected: String, spoken: String) -> Bool {
        let normalizedExpected = normalizeWord(expected)
        let normalizedSpoken = normalizeWord(spoken)
        
        // 1. Exact match (case-insensitive, punctuation-ignored)
        if normalizedSpoken == normalizedExpected {
            return true
        }
        
        // 2. Homonym matching
        if isHomonymMatch(expected: normalizedExpected, spoken: normalizedSpoken) {
            return true
        }
        
        // 3. Phonetic similarity matching
        if isPhoneticallySimilar(expected: normalizedExpected, spoken: normalizedSpoken) {
            return true
        }
        
        // 4. Common speech recognition error patterns
        if isCommonRecognitionError(expected: normalizedExpected, spoken: normalizedSpoken) {
            return true
        }
        
        return false
    }
    
    /// Normalize word for comparison (lowercase, remove punctuation, normalize apostrophes)
    private func normalizeWord(_ word: String) -> String {
        return word.lowercased()
            .trimmingCharacters(in: .punctuationCharacters)
            .replacingOccurrences(of: "'", with: "'")
            .replacingOccurrences(of: "\"", with: "'")
            .replacingOccurrences(of: "’", with: "'")
    }
    
    /// Check if words are homonyms (sound the same but spelled differently)
    private func isHomonymMatch(expected: String, spoken: String) -> Bool {
        let homonymGroups: [[String]] = [
            // Common homonyms
            ["soar", "sore"],
            ["their", "there", "they're"],
            ["to", "too", "two"],
            ["your", "you're"],
            ["its", "it's"],
            ["whose", "who's"],
            ["where", "wear", "ware"],
            ["here", "hear"],
            ["see", "sea"],
            ["meet", "meat"],
            ["write", "right", "rite"],
            ["read", "reed"],
            ["blue", "blew"],
            ["new", "knew"],
            ["know", "no"],
            ["one", "won"],
            ["son", "sun"],
            ["break", "brake"],
            ["peace", "piece"],
            ["plain", "plane"],
            ["rain", "reign", "rein"],
            ["sail", "sale"],
            ["sight", "site", "cite"],
            ["steal", "steel"],
            ["tail", "tale"],
            ["wait", "weight"],
            ["way", "weigh"],
            ["weak", "week"],
            ["weather", "whether"],
            ["wood", "would"],
            ["flower", "flour"],
            ["hole", "whole"],
            ["hour", "our"],
            ["mail", "male"],
            ["pair", "pear"],
            ["passed", "past"],
            ["principal", "principle"],
            ["stationary", "stationery"],
            ["through", "threw"],
            ["thrown", "throne"],
            ["vain", "vein"],
            ["waste", "waist"],
            ["bear", "bare"],
            ["board", "bored"],
            ["buy", "by", "bye"],
            ["cell", "sell"],
            ["cent", "scent", "sent"],
            ["coarse", "course"],
            ["dear", "deer"],
            ["die", "dye"],
            ["fair", "fare"],
            ["find", "fined"],
            ["for", "four", "fore"],
            ["hair", "hare"],
            ["heal", "heel"],
            ["hear", "here"],
            ["him", "hymn"],
            ["hole", "whole"],
            ["in", "inn"],
            ["knight", "night"],
            ["knot", "not"],
            ["know", "no"],
            ["made", "maid"],
            ["main", "mane"],
            ["meat", "meet"],
            ["morning", "mourning"],
            ["none", "nun"],
            ["oar", "or", "ore"],
            ["pale", "pail"],
            ["pear", "pair"],
            ["poor", "pour"],
            ["road", "rode"],
            ["role", "roll"],
            ["root", "route"],
            ["sail", "sale"],
            ["scene", "seen"],
            ["seam", "seem"],
            ["sew", "so", "sow"],
            ["shear", "sheer"],
            ["some", "sum"],
            ["stair", "stare"],
            ["steal", "steel"],
            ["straight", "strait"],
            ["suite", "sweet"],
            ["tear", "tier"],
            ["tied", "tide"],
            ["toe", "tow"],
            ["vain", "vein"],
            ["wail", "whale"],
            ["wait", "weight"],
            ["warn", "worn"],
            ["way", "weigh"],
            ["weak", "week"],
            ["weather", "whether"],
            ["which", "witch"],
            ["wood", "would"],
            ["wring", "ring"],
            ["write", "right", "rite"]
        ]
        
        for group in homonymGroups {
            if group.contains(expected) && group.contains(spoken) {
                return true
            }
        }
        
        return false
    }
    
    /// Check if words are phonetically similar using simple heuristics
    private func isPhoneticallySimilar(expected: String, spoken: String) -> Bool {
        // If words are very similar in length and have high character overlap
        let lengthDiff = abs(expected.count - spoken.count)
        if lengthDiff <= 1 {
            let commonChars = Set(expected).intersection(Set(spoken))
            let similarity = Double(commonChars.count) / Double(max(expected.count, spoken.count))
            if similarity >= 0.8 {
                return true
            }
        }
        
        // Common phonetic substitutions
        let phoneticSubstitutions: [(String, String)] = [
            ("th", "f"), ("th", "v"),  // "think" vs "fink"
            ("w", "v"), ("v", "w"),    // "very" vs "wery"
            ("l", "r"), ("r", "l"),    // "light" vs "right"
            ("s", "z"), ("z", "s"),    // "zoo" vs "soo"
            ("f", "v"), ("v", "f"),    // "very" vs "fery"
            ("p", "b"), ("b", "p"),    // "pat" vs "bat"
            ("t", "d"), ("d", "t"),    // "time" vs "dime"
            ("k", "g"), ("g", "k"),    // "cat" vs "gat"
            ("sh", "s"), ("s", "sh"),  // "ship" vs "sip"
            ("ch", "t"), ("t", "ch"),  // "chair" vs "tair"
            ("j", "d"), ("d", "j"),    // "jump" vs "dump"
            ("ng", "n"), ("n", "ng"),  // "sing" vs "sin"
            ("m", "n"), ("n", "m"),    // "man" vs "nan"
            ("w", "h"), ("h", "w"),    // "what" vs "wat"
            ("y", "i"), ("i", "y"),    // "yes" vs "ies"
            ("u", "oo"), ("oo", "u"),  // "put" vs "poot"
            ("a", "ah"), ("ah", "a"),  // "cat" vs "caht"
            ("e", "ee"), ("ee", "e"),  // "bed" vs "beed"
            ("i", "ee"), ("ee", "i"),  // "sit" vs "seet"
            ("o", "oh"), ("oh", "o"),  // "hot" vs "hoht"
            ("u", "you"), ("you", "u") // "use" vs "youse"
        ]
        
        for (sub1, sub2) in phoneticSubstitutions {
            if expected.replacingOccurrences(of: sub1, with: sub2) == spoken ||
               spoken.replacingOccurrences(of: sub1, with: sub2) == expected {
                return true
            }
        }
        
        return false
    }
    
    /// Check for common speech recognition error patterns
    private func isCommonRecognitionError(expected: String, spoken: String) -> Bool {
        let commonErrors: [(String, String)] = [
            // Common speech recognition confusions
            ("a", "uh"), ("uh", "a"),
            ("the", "duh"), ("duh", "the"),
            ("and", "an"), ("an", "and"),
            ("is", "it's"), ("it's", "is"),
            ("are", "our"), ("our", "are"),
            ("we're", "were"), ("were", "we're"),
            ("they're", "their"), ("their", "they're"),
            ("you're", "your"), ("your", "you're"),
            ("can't", "can"), ("can", "can't"),
            ("won't", "want"), ("want", "won't"),
            ("don't", "don"), ("don", "don't"),
            ("doesn't", "does"), ("does", "doesn't"),
            ("isn't", "is"), ("is", "isn't"),
            ("aren't", "are"), ("are", "aren't"),
            ("wasn't", "was"), ("was", "wasn't"),
            ("weren't", "were"), ("were", "weren't"),
            ("hasn't", "has"), ("has", "hasn't"),
            ("haven't", "have"), ("have", "haven't"),
            ("hadn't", "had"), ("had", "hadn't"),
            ("wouldn't", "would"), ("would", "wouldn't"),
            ("couldn't", "could"), ("could", "couldn't"),
            ("shouldn't", "should"), ("should", "shouldn't"),
            ("mightn't", "might"), ("might", "mightn't"),
            ("mustn't", "must"), ("must", "mustn't"),
            ("shan't", "shall"), ("shall", "shan't"),
            ("let's", "lets"), ("lets", "let's"),
            ("that's", "thats"), ("thats", "that's"),
            ("what's", "whats"), ("whats", "what's"),
            ("who's", "whos"), ("whos", "who's"),
            ("where's", "wheres"), ("wheres", "where's"),
            ("when's", "whens"), ("whens", "when's"),
            ("why's", "whys"), ("whys", "why's"),
            ("how's", "hows"), ("hows", "how's"),
            ("it's", "its"), ("its", "it's"),
            ("he's", "hes"), ("hes", "he's"),
            ("she's", "shes"), ("shes", "she's"),
            ("we're", "were"), ("were", "we're"),
            ("they're", "their"), ("their", "they're"),
            ("you're", "your"), ("your", "you're"),
            ("I'm", "im"), ("im", "I'm"),
            ("I'll", "ill"), ("ill", "I'll"),
            ("I've", "ive"), ("ive", "I've"),
            ("I'd", "id"), ("id", "I'd"),
            ("he'll", "hell"), ("hell", "he'll"),
            ("she'll", "shell"), ("shell", "she'll"),
            ("we'll", "well"), ("well", "we'll"),
            ("they'll", "theyll"), ("theyll", "they'll"),
            ("you'll", "youll"), ("youll", "you'll"),
            ("he's", "hes"), ("hes", "he's"),
            ("she's", "shes"), ("shes", "she's"),
            ("it's", "its"), ("its", "it's"),
            ("we've", "weve"), ("weve", "we've"),
            ("they've", "theyve"), ("theyve", "they've"),
            ("you've", "youve"), ("youve", "you've"),
            ("he'd", "hed"), ("hed", "he'd"),
            ("she'd", "shed"), ("shed", "she'd"),
            ("we'd", "wed"), ("wed", "we'd"),
            ("they'd", "theyd"), ("theyd", "they'd"),
            ("you'd", "youd"), ("youd", "you'd")
        ]
        
        for (error, correct) in commonErrors {
            if expected == correct && spoken == error {
                return true
            }
        }
        
        return false
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
        // print("[DEBUG] analyzeTranscription")
        // print("[DEBUG] Transcription: \(transcription)")
        // print("[DEBUG] Spoken words: \(spokenWords)")
        // print("[DEBUG] Expected word (raw): \(expectedWordRaw)")
        // print("[DEBUG] Expected word (processed): \(expectedWord)")
        
        // Use the new comprehensive word matching system
        let userSpoken = spokenWords.first { spokenWord in
            isWordMatch(expected: expectedWord, spoken: spokenWord)
        }
        
        let isCorrect = userSpoken != nil
        let isMissing = spokenWords.isEmpty || !spokenWords.contains { isWordMatch(expected: expectedWord, spoken: $0) }
        let isMispronounced = !isMissing && !isCorrect
        
        // print("[DEBUG] isCorrect: \(isCorrect), isMissing: \(isMissing), isMispronounced: \(isMispronounced)")
        
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
    
    // Public method to skip the current word
    mutating func skipCurrentWord() {
        advanceToNextWord()
    }
} 