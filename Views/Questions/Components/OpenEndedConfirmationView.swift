import SwiftUI

struct OpenEndedConfirmationView: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let answeredQuestions: Int
    let totalQuestions: Int
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Complete Open-Ended Section")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("You're about to complete the open-ended questions section. Your answers will be locked and cannot be changed.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Answer summary
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("\(answeredQuestions) of \(totalQuestions) questions answered")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                
                // Warning message
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Important")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                    
                    Text("Once you proceed, you won't be able to change your open-ended answers.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: onConfirm) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Yes, Complete Section")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    
                    Button(action: onCancel) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("No, Let Me Review")
                        }
                        .font(.headline)
                        .foregroundColor(.green)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}
