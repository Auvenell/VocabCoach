import Foundation

/// Comprehensive word matching system that handles homonyms, phonetic similarity, and common speech recognition errors
class WordMatcher {
    static let shared = WordMatcher()
    
    private init() {}
    
    /// Check if two words match, considering homonyms, phonetic similarity, and common speech recognition errors
    func isWordMatch(expected: String, spoken: String) -> Bool {
        let normalizedExpected = normalizeWord(expected)
        let normalizedSpoken = normalizeWord(spoken)
        
        // 1. Exact match (case-insensitive, punctuation-ignored)
        if normalizedSpoken == normalizedExpected {
            return true
        }
        
        // 2. Possessive form matching
        if isPossessiveMatch(expected: normalizedExpected, spoken: normalizedSpoken) {
            return true
        }
        
        // 3. Homonym matching
        if isHomonymMatch(expected: normalizedExpected, spoken: normalizedSpoken) {
            return true
        }
        
        // 4. Phonetic similarity matching
        if isPhoneticallySimilar(expected: normalizedExpected, spoken: normalizedSpoken) {
            return true
        }
        
        // 5. Common speech recognition error patterns
        if isCommonRecognitionError(expected: normalizedExpected, spoken: normalizedSpoken) {
            return true
        }
        
        return false
    }
    
    /// Normalize word for comparison (lowercase, remove punctuation, normalize apostrophes)
    private func normalizeWord(_ word: String) -> String {
        return word.lowercased()
            .trimmingCharacters(in: .punctuationCharacters)
            .replacingOccurrences(of: "’", with: "'") // curly to straight
            .replacingOccurrences(of: "'", with: "'")
            .replacingOccurrences(of: "\"", with: "'")
    }
    
    /// Check if words are possessive forms of each other
    private func isPossessiveMatch(expected: String, spoken: String) -> Bool {
        // Handle cases like "industry's" vs "industries"
        
        // Case 1: Expected is possessive, spoken is plural
        if expected.hasSuffix("'s") {
            let baseWord = String(expected.dropLast(2)) // Remove "'s"
            if spoken == baseWord + "s" || spoken == baseWord + "es" {
                return true
            }
            // Handle y -> ies (e.g., industry's vs industries)
            if baseWord.hasSuffix("y") {
                let stem = String(baseWord.dropLast())
                if spoken == stem + "ies" {
                    return true
                }
            }
        }
        
        // Case 2: Expected is plural, spoken is possessive
        if expected.hasSuffix("s") && !expected.hasSuffix("'s") {
            if spoken == expected + "'s" {
                return true
            }
            // Handle ies -> y's (e.g., industries vs industry's)
            if expected.hasSuffix("ies") {
                let stem = String(expected.dropLast(3))
                if spoken == stem + "y's" {
                    return true
                }
            }
        }
        
        // Case 3: Handle irregular plurals that might be confused with possessives
        let irregularPossessives: [(String, String)] = [
            ("children's", "children"),
            ("men's", "men"),
            ("women's", "women"),
            ("people's", "people"),
            ("mice's", "mice"),
            ("geese's", "geese"),
            ("feet's", "feet"),
            ("teeth's", "teeth"),
            ("knives's", "knives"),
            ("lives's", "lives"),
            ("wives's", "wives"),
            ("wolves's", "wolves"),
            ("leaves's", "leaves"),
            ("shelves's", "shelves"),
            ("calves's", "calves"),
            ("halves's", "halves"),
            ("thieves's", "thieves"),
            ("loaves's", "loaves"),
            ("scarves's", "scarves"),
            ("wharves's", "wharves"),
            ("hooves's", "hooves"),
            ("dwarves's", "dwarves"),
            ("elves's", "elves"),
            ("selves's", "selves"),
            ("books's", "books"),
            ("looks's", "looks"),
            ("cooks's", "cooks"),
            ("takes's", "takes"),
            ("makes's", "makes"),
            ("gives's", "gives"),
            ("comes's", "comes"),
            ("does's", "does"),
            ("says's", "says"),
            ("goes's", "goes"),
            ("knows's", "knows"),
            ("shows's", "shows"),
            ("grows's", "grows"),
            ("throws's", "throws"),
            ("blows's", "blows"),
            ("flows's", "flows"),
            ("glows's", "glows"),
            ("slows's", "slows"),
            ("stows's", "stows"),
            ("tows's", "tows"),
            ("rows's", "rows"),
            ("sows's", "sows"),
            ("mows's", "mows"),
            ("bows's", "bows"),
            ("cows's", "cows"),
            ("vows's", "vows"),
            ("pows's", "pows"),
            ("jows's", "jows"),
            ("lows's", "lows"),
            ("nows's", "nows"),
            ("how's", "how"),
            ("what's", "what"),
            ("where's", "where"),
            ("when's", "when"),
            ("why's", "why"),
            ("who's", "who"),
            ("it's", "it"),
            ("he's", "he"),
            ("she's", "she"),
            ("we're", "we"),
            ("they're", "they"),
            ("you're", "you"),
            ("I'm", "I"),
            ("I'll", "I"),
            ("I've", "I"),
            ("I'd", "I"),
            ("he'll", "he"),
            ("she'll", "she"),
            ("we'll", "we"),
            ("they'll", "they"),
            ("you'll", "you"),
            ("he'd", "he"),
            ("she'd", "she"),
            ("we'd", "we"),
            ("they'd", "they"),
            ("you'd", "you"),
            ("he's", "he"),
            ("she's", "she"),
            ("it's", "it"),
            ("we've", "we"),
            ("they've", "they"),
            ("you've", "you")
        ]
        
        for (possessive, base) in irregularPossessives {
            if (expected == possessive && spoken == base) || (expected == base && spoken == possessive) {
                return true
            }
        }
        
        return false
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
} 