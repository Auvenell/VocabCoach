//
//  VocabularyService.swift
//  VocabCoach
//
//  Created by Aunik Paul on 8/6/25.
//

import UIKit
import Foundation

// MARK: - Vocabulary Service

class VocabularyService: ObservableObject {
    
    // Get important words from the article for vocabulary practice
    func getImportantWordsFromArticle(practiceSession: ReadingSession?) -> [String] {
        guard let session = practiceSession else { return [] }
        
        // Get all important words from the article
        let importantWords = session.paragraph.words.filter { word in
            WordClassifier.isImportantWord(word)
        }
        
        // Remove duplicates and common words, then take up to 5 words
        let uniqueImportantWords = Array(Set(importantWords))
            .filter { word in
                // Filter out very common words
                let commonWords = ["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "is", "are", "was", "were", "be", "been", "have", "has", "had", "do", "does", "did", "will", "would", "could", "should", "may", "might", "can", "this", "that", "these", "those", "it", "its", "they", "them", "their", "we", "you", "he", "she", "his", "her", "my", "your", "our", "us", "me", "him", "i"]
                return !commonWords.contains(word.lowercased())
            }
            .prefix(5)
            .sorted()
            .map { word in
                // Remove punctuation and capitalize first letter
                let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
                return cleanWord.prefix(1).uppercased() + cleanWord.dropFirst().lowercased()
            }
        
        return Array(uniqueImportantWords)
    }
    
    // Show Apple's built-in dictionary for a word
    func showDictionary(for word: String) -> UIReferenceLibraryViewController? {
        let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
        if UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: cleanWord) {
            return UIReferenceLibraryViewController(term: cleanWord)
        }
        return nil
    }
    
    // Check if dictionary has definition for a word
    func hasDictionaryDefinition(for word: String) -> Bool {
        let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
        return UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: cleanWord)
    }
    
    // Clean and format word for display
    func cleanAndFormatWord(_ word: String) -> String {
        let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
        return cleanWord.prefix(1).uppercased() + cleanWord.dropFirst().lowercased()
    }
    
    // Get vocabulary words from incorrect important words set
    func getVocabularyWordsFromSession(practiceSession: ReadingSession?) -> [String] {
        guard let session = practiceSession, !session.incorrectImportantWordsSet.isEmpty else {
            return getImportantWordsFromArticle(practiceSession: practiceSession)
        }
        return Array(session.incorrectImportantWordsSet)
    }
}