import SwiftUI

struct PracticeView: View {
    @StateObject private var speechManager = SpeechRecognitionManager()
    @StateObject private var ttsManager = TextToSpeechManager()
    @StateObject private var dataManager = ParagraphDataManager()
    
    @State private var currentSession: ReadingSession?
    @State private var selectedParagraph: PracticeParagraph?
    @State private var showingParagraphSelector = false
    @State private var showingResults = false
    @State private var feedbackMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let session = currentSession {
                    practiceSessionView(session: session)
                } else {
                    welcomeView
                }
            }
            .padding()
            .navigationTitle("VocabCoach")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Select Text") {
                        showingParagraphSelector = true
                    }
                }
            }
            .sheet(isPresented: $showingParagraphSelector) {
                ParagraphSelectorView(
                    dataManager: dataManager,
                    selectedParagraph: $selectedParagraph,
                    onParagraphSelected: { paragraph in
                        selectedParagraph = paragraph
                        showingParagraphSelector = false
                        startNewSession(with: paragraph)
                    }
                )
            }
            .alert("Feedback", isPresented: .constant(!feedbackMessage.isEmpty)) {
                Button("OK") {
                    feedbackMessage = ""
                }
            } message: {
                Text(feedbackMessage)
            }
        }
        .onReceive(speechManager.$transcribedText) { transcription in
            if currentSession != nil, !transcription.isEmpty {
                updateSession(with: transcription)
            }
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 30) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Welcome to VocabCoach")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Improve your English pronunciation and fluency by reading aloud and getting real-time feedback.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: {
                showingParagraphSelector = true
            }) {
                Text("Start Practice")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func practiceSessionView(session: ReadingSession) -> some View {
        VStack(spacing: 20) {
            // Paragraph display
            TappableTextView(
                paragraph: session.paragraph,
                wordAnalyses: session.wordAnalyses,
                onWordTap: { word in
                    handleWordTap(word)
                }
            )
            
            // Transcription view
            TranscriptionView(
                transcribedText: speechManager.transcribedText,
                confidence: speechManager.confidence
            )
            
            // Start/Stop Reading button (prominent)
            Button(action: {
                if speechManager.isListening {
                    stopPractice()
                } else {
                    startPractice()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: speechManager.isListening ? "waveform.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .shadow(color: speechManager.isListening ? .blue.opacity(0.7) : .clear, radius: 10, x: 0, y: 0)
                        .scaleEffect(speechManager.isListening ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: speechManager.isListening)
                    Text(speechManager.isListening ? "Stop" : "Start Reading")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(speechManager.isListening ? Color.red : Color.green)
                .cornerRadius(16)
                .shadow(color: speechManager.isListening ? .blue.opacity(0.5) : .clear, radius: 10, x: 0, y: 0)
            }
            .padding(.top, 16)
            .accessibilityLabel(speechManager.isListening ? "Stop Listening" : "Start Reading")
            
            // Progress indicator
            if session.totalWords > 0 {
                VStack(spacing: 8) {
                    HStack {
                        Text("Progress:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(session.correctWords)/\(session.totalWords) words")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: session.accuracy)
                        .progressViewStyle(LinearProgressViewStyle())
                        .accentColor(session.accuracy > 0.8 ? .green : session.accuracy > 0.6 ? .orange : .red)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            Spacer()
        }
    }
    
    private func startNewSession(with paragraph: PracticeParagraph) {
        currentSession = ReadingSession(paragraph: paragraph)
        speechManager.reset()
        ttsManager.stopSpeaking()
    }
    
    private func startPractice() {
        guard var session = currentSession else { return }
        
        session.startTime = Date()
        currentSession = session
        speechManager.startListening()
        
        // Provide initial feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ttsManager.speakFeedback("Begin reading the paragraph aloud")
        }
    }
    
    private func stopPractice() {
        guard var session = currentSession else { return }
        
        session.endTime = Date()
        speechManager.stopListening()
        currentSession = session
        
        // Provide final feedback
        let accuracy = session.accuracy
        let feedback: String
        
        if accuracy >= 0.9 {
            feedback = "Excellent reading! Your pronunciation was very accurate."
        } else if accuracy >= 0.7 {
            feedback = "Good job! You're making great progress with your pronunciation."
        } else if accuracy >= 0.5 {
            feedback = "Keep practicing! Focus on the highlighted words for improvement."
        } else {
            feedback = "Don't worry, pronunciation takes time. Try reading more slowly and clearly."
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ttsManager.speakFeedback(feedback)
        }
    }
    
    private func updateSession(with transcription: String) {
        guard var session = currentSession else { return }
        
        session.analyzeTranscription(transcription, confidence: speechManager.confidence)
        currentSession = session
        
        // Provide real-time feedback for significant errors
        let missingWords = session.wordAnalyses.filter { $0.isMissing }.count
        let mispronouncedWords = session.wordAnalyses.filter { $0.isMispronounced }.count
        
        if missingWords > 0 || mispronouncedWords > 0 {
            let totalErrors = missingWords + mispronouncedWords
            if totalErrors == 1 {
                feedbackMessage = "Try to pronounce that word more clearly"
            } else if totalErrors <= 3 {
                feedbackMessage = "Focus on pronouncing each word carefully"
            }
        }
    }
    
    private func handleWordTap(_ word: String) {
        ttsManager.speakWord(word)
    }
    
    private func resetSession() {
        guard let paragraph = currentSession?.paragraph else { return }
        startNewSession(with: paragraph)
    }
}

struct ParagraphSelectorView: View {
    @ObservedObject var dataManager: ParagraphDataManager
    @Binding var selectedParagraph: PracticeParagraph?
    let onParagraphSelected: (PracticeParagraph) -> Void
    
    @State private var selectedDifficulty: PracticeParagraph.Difficulty?
    @State private var selectedCategory: PracticeParagraph.Category?
    
    var body: some View {
        NavigationView {
            VStack {
                // Filter controls
                VStack(spacing: 16) {
                    HStack {
                        Text("Difficulty:")
                            .font(.headline)
                        Spacer()
                        Picker("Difficulty", selection: $selectedDifficulty) {
                            Text("All").tag(nil as PracticeParagraph.Difficulty?)
                            ForEach(PracticeParagraph.Difficulty.allCases, id: \.self) { difficulty in
                                Text(difficulty.rawValue).tag(difficulty as PracticeParagraph.Difficulty?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    HStack {
                        Text("Category:")
                            .font(.headline)
                        Spacer()
                        Picker("Category", selection: $selectedCategory) {
                            Text("All").tag(nil as PracticeParagraph.Category?)
                            ForEach(PracticeParagraph.Category.allCases, id: \.self) { category in
                                Text(category.rawValue).tag(category as PracticeParagraph.Category?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Paragraph list
                List {
                    ForEach(filteredParagraphs) { paragraph in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(paragraph.title)
                                .font(.headline)
                            
                            Text(paragraph.text)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                            
                            HStack {
                                Text(paragraph.difficulty.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(difficultyColor(for: paragraph.difficulty))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                
                                Text(paragraph.category.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                
                                Spacer()
                                
                                Text("\(paragraph.words.count) words")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onParagraphSelected(paragraph)
                        }
                    }
                }
            }
            .navigationTitle("Select Practice Text")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var filteredParagraphs: [PracticeParagraph] {
        dataManager.getParagraphs(for: selectedDifficulty, category: selectedCategory)
    }
    
    private func difficultyColor(for difficulty: PracticeParagraph.Difficulty) -> Color {
        switch difficulty {
        case .beginner:
            return .green
        case .intermediate:
            return .orange
        case .advanced:
            return .red
        }
    }
} 
