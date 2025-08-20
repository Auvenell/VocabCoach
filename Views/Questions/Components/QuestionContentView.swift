import SwiftUI

struct QuestionContentView: View {
    let section: QuestionSection
    let question: Any
    let questionIndex: Int
    @Binding var selectedAnswers: [String: String]
    @Binding var openEndedAnswers: [String: String]
    @Binding var editingAnswers: [String: String]
    @Binding var lockedAnswers: Set<String>
    @Binding var recordingQuestion: String?
    @Binding var vocabularyAnswers: [String: String]
    @Binding var vocabularyEditingAnswers: [String: String]
    @Binding var vocabularyLockedAnswers: Set<String>
    @Binding var recordingVocabularyWord: String?
    let speechManager: SpeechRecognitionManager
    let onWordTap: (String) -> Void
    let onMultipleChoiceAnswer: (Bool, Int, String, String, String, String, String) -> Void // isCorrect, questionNumber, questionText, studentChoice, correctChoice, studentChoiceText, correctChoiceText
    let onOpenEndedAnswer: (Bool) -> Void
    let onVocabularyAnswer: (Bool) -> Void
    let articleContent: String
    let evaluateWithLLM: (String, String, String, String, Int) async -> Bool
    let multipleChoiceSectionCompleted: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question content based on section type
            switch section {
            case .multipleChoice:
                if let mcQuestion = question as? MultipleChoiceQuestion {
                    MultipleChoiceQuestionView(
                        question: mcQuestion,
                        questionNumber: questionIndex + 1,
                        selectedAnswer: selectedAnswers[mcQuestion.questionText],
                        isSectionCompleted: multipleChoiceSectionCompleted,
                        onAnswerSelected: { answer in
                            // Only allow selection if section is not completed
                            guard !multipleChoiceSectionCompleted else { 
                                print("Multiple choice section completed - cannot change answers")
                                return 
                            }
                            
                            selectedAnswers[mcQuestion.questionText] = answer
                            // Track if answer is correct
                            // Convert the answer reference (A, B, C, D) to the actual choice text
                            let correctAnswerText = getCorrectAnswerText(for: mcQuestion)
                            let isCorrect = answer == correctAnswerText
                            
                            // Convert the full answer text to choice letter format
                            let choiceMapping = [
                                mcQuestion.choices[0]: "choice_a",
                                mcQuestion.choices[1]: "choice_b", 
                                mcQuestion.choices[2]: "choice_c",
                                mcQuestion.choices[3]: "choice_d"
                            ]
                            let studentChoice = choiceMapping[answer] ?? ""
                            let correctChoice = mcQuestion.answer // Already in choice_a format
                            
                            // Call the new tracking function with choice letter format and choice text
                            onMultipleChoiceAnswer(isCorrect, questionIndex + 1, mcQuestion.questionText, studentChoice, correctChoice, answer, getCorrectAnswerText(for: mcQuestion))
                            
                            // Debug logging
                            print("Multiple Choice Question: \(mcQuestion.questionText)")
                            print("Selected Answer: \(answer)")
                            print("Student Choice: \(studentChoice)")
                            print("Correct Choice: \(correctChoice)")
                            print("Is Correct: \(isCorrect)")
                        }
                    )
                }
            case .openEnded:
                if let oeQuestion = question as? ComprehensionQuestion {
                    OpenEndedQuestionView(
                        questionNumber: questionIndex + 1,
                        question: oeQuestion,
                        answer: openEndedAnswers[oeQuestion.questionText] ?? "",
                        editingAnswer: editingAnswers[oeQuestion.questionText] ?? "",
                        isLocked: lockedAnswers.contains(oeQuestion.questionText),
                        isRecording: recordingQuestion == oeQuestion.questionText,
                        transcribedText: speechManager.transcribedText,
                        onStartRecording: {
                            startRecording(for: oeQuestion.questionText)
                        },
                        onStopRecording: {
                            stopRecording(for: oeQuestion.questionText)
                        },
                        onAnswerChanged: { newAnswer in
                            editingAnswers[oeQuestion.questionText] = newAnswer
                        },
                        onLockAnswer: {
                            lockAnswer(for: oeQuestion.questionText)
                            // Evaluate open-ended answer using LLM
                            let userAnswer = openEndedAnswers[oeQuestion.questionText] ?? ""
                            let expectedAnswer = oeQuestion.answer
                            
                            Task {
                                let isCorrect = await evaluateWithLLM(
                                    articleContent.isEmpty ? "No article content available" : articleContent,
                                    oeQuestion.questionText,
                                    expectedAnswer,
                                    userAnswer,
                                    questionIndex + 1
                                )
                                
                                await MainActor.run {
                                    onOpenEndedAnswer(isCorrect)
                                    
                                    // Debug logging
                                    print("Open-Ended Question (LLM): \(oeQuestion.questionText)")
                                    print("User Answer: \(userAnswer)")
                                    print("Expected Answer: \(expectedAnswer)")
                                    print("Is Correct: \(isCorrect)")
                                }
                            }
                        }
                    )
                }
            case .vocabulary:
                if let word = question as? String {
                    VocabularyWordView(
                        wordNumber: questionIndex + 1,
                        word: word,
                        answer: vocabularyAnswers[word] ?? "",
                        editingAnswer: vocabularyEditingAnswers[word] ?? "",
                        isLocked: vocabularyLockedAnswers.contains(word),
                        isRecording: recordingVocabularyWord == word,
                        transcribedText: speechManager.transcribedText,
                        onWordTap: {
                            onWordTap(word)
                        },
                        onStartRecording: {
                            startVocabularyRecording(for: word)
                        },
                        onStopRecording: {
                            stopVocabularyRecording(for: word)
                        },
                        onAnswerChanged: { newAnswer in
                            vocabularyEditingAnswers[word] = newAnswer
                        },
                        onLockAnswer: {
                            lockVocabularyAnswer(for: word)
                            // Track vocabulary answer as correct if it has content
                            let hasAnswer = !(vocabularyAnswers[word] ?? "").isEmpty
                            onVocabularyAnswer(hasAnswer)
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // Helper functions for recording
    private func startRecording(for questionText: String) {
        recordingQuestion = questionText
        speechManager.startListening()
    }
    
    private func stopRecording(for questionText: String) {
        recordingQuestion = nil
        speechManager.stopListening()
        openEndedAnswers[questionText] = editingAnswers[questionText] ?? ""
    }
    
    private func lockAnswer(for questionText: String) {
        lockedAnswers.insert(questionText)
        openEndedAnswers[questionText] = editingAnswers[questionText] ?? ""
    }
    
    private func startVocabularyRecording(for word: String) {
        recordingVocabularyWord = word
        speechManager.startListening()
    }
    
    private func stopVocabularyRecording(for word: String) {
        recordingVocabularyWord = nil
        speechManager.stopListening()
        vocabularyAnswers[word] = vocabularyEditingAnswers[word] ?? ""
    }
    
    private func lockVocabularyAnswer(for word: String) {
        vocabularyLockedAnswers.insert(word)
        vocabularyAnswers[word] = vocabularyEditingAnswers[word] ?? ""
    }
}

// Helper function to get the correct answer text from the choice reference
private func getCorrectAnswerText(for question: MultipleChoiceQuestion) -> String {
    // The answer field contains "choice_a", "choice_b", etc.
    // We need to map this to the actual choice text
    let choiceMapping = [
        "choice_a": 0,
        "choice_b": 1,
        "choice_c": 2,
        "choice_d": 3
    ]
    
    guard let choiceIndex = choiceMapping[question.answer],
          choiceIndex < question.choices.count else {
        print("Invalid choice reference: \(question.answer)")
        return ""
    }
    
    return question.choices[choiceIndex]
}
