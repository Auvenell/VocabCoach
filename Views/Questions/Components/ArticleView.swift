import SwiftUI

struct ArticleView: View {
    let articleId: String
    let practiceSession: ReadingSession?
    @StateObject private var viewModel = ArticleViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if let session = practiceSession {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(session.paragraph.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            Text(session.paragraph.text)
                                .font(.body)
                                .lineSpacing(4)
                                .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                } else {
                    VStack {
                        ProgressView("Loading article...")
                            .padding()
                    }
                }
            }
            .navigationTitle("Article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Load article data if needed
            if practiceSession == nil {
                // Handle case where we need to load article data
                // This would depend on your data structure
            }
        }
    }
}
