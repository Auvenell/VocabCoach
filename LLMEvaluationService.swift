import Foundation
import FirebaseFirestore

class LLMEvaluationService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    // LLM API configuration
    private let apiKey = "your-api-key" // Replace with your actual API key
    private let openAIBaseURL = "https://api.openai.com/v1/chat/completions"
    private let localLLMBaseURL = "http://192.168.1.65:11434/v1/chat/completions"
    
    // Configuration
    private let useLocalLLM = true // Set to false to use OpenAI instead
    
    struct EvaluationRequest {
        let article: String
        let questionText: String
        let expectedAnswer: String
        let studentAnswer: String
        let prompt: String
    }
    
    struct EvaluationResponse {
        let score: Double // 0.0 to 1.0
        let feedback: String
        let reasoning: String
    }
    
    func evaluateOpenEndedAnswer(
        article: String,
        questionText: String,
        expectedAnswer: String,
        studentAnswer: String
    ) async -> EvaluationResponse? {
        await MainActor.run {
            isLoading = true
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        let prompt = """
        You are an expert English teacher evaluating a student's answer to a reading comprehension question. 
        
        You respond only with a JSON object containing the following fields:
        - isCorrect: true/false
        - score: 0.0-1.0
        - feedback: brief feedback for the student
        - reasoning: explanation of your evaluation

        Example response format:
        {
            "isCorrect": true,
            "score": 0.85,
            "feedback": "Good answer! You correctly identified the main point about climate change.",
            "reasoning": "The student's answer accurately captures the key concept from the article and provides relevant details."
        }

        Article: \(article)
        
        Question: \(questionText)
        
        Expected Answer: \(expectedAnswer)
        
        Student's Answer: \(studentAnswer)
        
        Please evaluate the student's answer based on the expected answer. Consider:
        1. Does the student's answer address the key points from the expected answer?
        2. Is the answer factually accurate according to the article?
        3. Is the answer complete and well-formed?
        """
        
        let request = EvaluationRequest(
            article: article,
            questionText: questionText,
            expectedAnswer: expectedAnswer,
            studentAnswer: studentAnswer,
            prompt: prompt
        )
        
        return await sendToLLM(request: request)
    }
    
    private func sendToLLM(request: EvaluationRequest) async -> EvaluationResponse? {
        if useLocalLLM {
            return await callLocalLLM(request: request)
        } else {
            return await callOpenAI(request: request)
        }
    }
    
    private func callLocalLLM(request: EvaluationRequest) async -> EvaluationResponse? {
        guard let url = URL(string: localLLMBaseURL) else {
            await MainActor.run {
                errorMessage = "Invalid local LLM URL"
            }
            return nil
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30.0 // 30 second timeout
        
        // Prepare the request body for local LLM (OpenAI-compatible format)
        let requestBody: [String: Any] = [
            "model": "local-model", // Your local model name
            "messages": [
                [
                    "role": "user",
                    "content": request.prompt
                ]
            ],
            "max_tokens": 500,
            "temperature": 0.1,
            "stop": ["\n\n", "Human:", "Assistant:"]
        ]
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Local LLM Response Status: \(httpResponse.statusCode)")
            }
            
            // Parse the response
            if let responseString = String(data: data, encoding: .utf8) {
                print("Local LLM Raw Response: \(responseString)")
                return parseLocalLLMResponse(responseString)
            } else {
                await MainActor.run {
                    errorMessage = "Failed to decode LLM response"
                }
                return nil
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Local LLM API error: \(error.localizedDescription)"
            }
            print("Local LLM Error: \(error)")
            return nil
        }
    }
    
    private func parseLocalLLMResponse(_ response: String) -> EvaluationResponse? {
        // Try to parse OpenAI-compatible response format
        do {
            let data = response.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            // Extract the content from OpenAI-compatible response
            if let choices = json?["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                
                // Extract JSON from markdown code blocks (```json ... ```)
                if let jsonContent = extractJSONFromMarkdown(content) {
                    return parseJSONResponse(jsonContent)
                }
                
                // Try to extract JSON from the content (fallback)
                let jsonPattern = "\\{[^}]*\"isCorrect\"[^}]*\\}"
                if let range = content.range(of: jsonPattern, options: .regularExpression) {
                    let jsonString = String(content[range])
                    return parseJSONResponse(jsonString)
                }
                
                // If no JSON found, try to infer from the content
                let lowerContent = content.lowercased()
                let isCorrect = lowerContent.contains("correct") || lowerContent.contains("good") || lowerContent.contains("accurate")
                let score = isCorrect ? 0.8 : 0.3
                
                return EvaluationResponse(
                    score: score,
                    feedback: "LLM evaluation completed",
                    reasoning: content
                )
            }
        } catch {
            print("Failed to parse OpenAI-compatible response: \(error)")
        }
        
        // Fallback: try to extract JSON from the raw response
        if let jsonContent = extractJSONFromMarkdown(response) {
            return parseJSONResponse(jsonContent)
        }
        
        let jsonPattern = "\\{[^}]*\"isCorrect\"[^}]*\\}"
        if let range = response.range(of: jsonPattern, options: .regularExpression) {
            let jsonString = String(response[range])
            return parseJSONResponse(jsonString)
        }
        
        // If no JSON found, try to infer from the response
        let lowerResponse = response.lowercased()
        let isCorrect = lowerResponse.contains("correct") || lowerResponse.contains("good") || lowerResponse.contains("accurate")
        let score = isCorrect ? 0.8 : 0.3
        
        return EvaluationResponse(
            score: score,
            feedback: "LLM evaluation completed",
            reasoning: response
        )
    }
    
    private func extractJSONFromMarkdown(_ content: String) -> String? {
        // Pattern to match ```json ... ``` blocks
        let pattern = "```json\\s*([\\s\\S]*?)\\s*```"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        
        let range = NSRange(location: 0, length: content.utf16.count)
        guard let match = regex.firstMatch(in: content, options: [], range: range) else {
            return nil
        }
        
        // Extract the JSON content from the first capture group
        let jsonRange = match.range(at: 1)
        guard jsonRange.location != NSNotFound else {
            return nil
        }
        
        let startIndex = content.index(content.startIndex, offsetBy: jsonRange.location)
        let endIndex = content.index(startIndex, offsetBy: jsonRange.length)
        let jsonContent = String(content[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        return jsonContent
    }
    
    private func parseJSONResponse(_ jsonString: String) -> EvaluationResponse? {
        do {
            let data = jsonString.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            let score = json?["score"] as? Double ?? 0.0
            let feedback = json?["feedback"] as? String ?? "No feedback provided"
            let reasoning = json?["reasoning"] as? String ?? "No reasoning provided"
            
            return EvaluationResponse(
                score: score,
                feedback: feedback,
                reasoning: reasoning
            )
        } catch {
            print("JSON parsing error: \(error)")
            return nil
        }
    }
    
    private func callOpenAI(request: EvaluationRequest) async -> EvaluationResponse? {
        // OpenAI implementation (for future use)
        return nil
    }
    

} 