import SwiftUI

struct NavigationControlsView: View {
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onShowArticle: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onPrevious) {
                HStack {
                    Image(systemName: "chevron.left")
                }
                .foregroundColor(canGoPrevious ? .blue : .gray)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(canGoPrevious ? Color.blue : Color.gray, lineWidth: 1)
                )
            }
            .disabled(!canGoPrevious)
            .frame(width: 60)
            
            Spacer()
            
            Button(action: onShowArticle) {
                HStack {
                    Image(systemName: "doc.text")
                    Text("See Reading")
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 1)
                )
            }
            
            Spacer()
            
            Button(action: onNext) {
                HStack {
                    Image(systemName: "chevron.right")
                }
                .foregroundColor(canGoNext ? .white : .gray)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(canGoNext ? Color.blue : Color.gray)
                )
            }
            .disabled(!canGoNext)
            .frame(width: 60)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4)),
            alignment: .top
        )
    }
}
