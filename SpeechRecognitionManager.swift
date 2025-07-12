import Foundation
import Speech
import AVFoundation

class SpeechRecognitionManager: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var transcribedText = ""
    @Published var confidence: Float = 0.0
    @Published var errorMessage: String?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    override init() {
        super.init()
        requestSpeechAuthorization()
    }
    
    func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.errorMessage = nil
                    print("Speech recognition authorized")
                case .denied:
                    self?.errorMessage = "Speech recognition permission denied"
                    print("Speech recognition permission denied")
                case .restricted:
                    self?.errorMessage = "Speech recognition restricted on this device"
                    print("Speech recognition restricted on this device")
                case .notDetermined:
                    self?.errorMessage = "Speech recognition not yet authorized"
                    print("Speech recognition not yet authorized")
                @unknown default:
                    self?.errorMessage = "Speech recognition authorization failed"
                    print("Speech recognition authorization failed")
                }
            }
        }
    }
    
    func startListening() {
        guard !isListening else { print("Already listening"); return }
        print("startListening called")
        
        // Reset state
        transcribedText = ""
        confidence = 0.0
        errorMessage = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("Audio session configured and activated")
        } catch {
            errorMessage = "Failed to configure audio session: \(error.localizedDescription)"
            print("Failed to configure audio session: \(error.localizedDescription)")
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Unable to create speech recognition request"
            print("Unable to create speech recognition request")
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Recognition error: \(error.localizedDescription)"
                    print("Recognition error: \(error.localizedDescription)")
                    self.stopListening()
                }
                return
            }
            
            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                    self.confidence = result.bestTranscription.segments.map { $0.confidence }.reduce(0, +) / Float(result.bestTranscription.segments.count)
                    print("Transcribed: \(self.transcribedText) | Confidence: \(self.confidence)")
                }
            }
        }
        
        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            print("Audio engine started, now listening...")
        } catch {
            errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            print("Failed to start audio engine: \(error.localizedDescription)")
            return
        }
    }
    
    func stopListening() {
        guard isListening else { print("Not currently listening"); return }
        print("stopListening called")
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        isListening = false
        print("Stopped listening")
    }
    
    func reset() {
        stopListening()
        transcribedText = ""
        confidence = 0.0
        errorMessage = nil
        print("SpeechRecognitionManager reset")
    }
    
    func clearTranscription() {
        transcribedText = ""
        print("Transcription cleared")
    }
} 