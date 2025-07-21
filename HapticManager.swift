import Foundation
import UIKit

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    // Reusable feedback generators
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    // Light impact for general feedback
    func lightImpact() {
        lightImpactGenerator.prepare()
        lightImpactGenerator.impactOccurred()
    }
    
    // Medium impact for more noticeable feedback
    func mediumImpact() {
        mediumImpactGenerator.prepare()
        mediumImpactGenerator.impactOccurred()
    }
    
    // Heavy impact for significant events
    func heavyImpact() {
        heavyImpactGenerator.prepare()
        heavyImpactGenerator.impactOccurred()
    }
    
    // Notification feedback for word added to practice list
    func wordAddedToPractice() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.success)
    }
    
    // Error feedback for mispronunciations
    func errorFeedback() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.error)
    }
    
    // Warning feedback for partial issues
    func warningFeedback() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.warning)
    }
} 