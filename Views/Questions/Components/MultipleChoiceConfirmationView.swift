import SwiftUI

struct MultipleChoiceConfirmationView: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let answeredQuestions: Int
    let totalQuestions: Int
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Lock Multiple Choice Answers")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("You're about to complete the multiple choice section. Your answers will be locked and cannot be changed.")
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
                    
                    Text("Once you proceed, you won't be able to change your multiple choice answers.")
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
                            Text("Yes, Lock My Answers")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    Button(action: onCancel) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("No, Let Me Review")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 1)
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
