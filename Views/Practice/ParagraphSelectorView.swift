import SwiftUI

struct ParagraphSelectorView: View {
    @ObservedObject var dataManager: ParagraphDataManager
    @Binding var selectedParagraph: PracticeParagraph?
    let onParagraphSelected: (PracticeParagraph) -> Void

    @State private var selectedDifficulty: PracticeParagraph.Difficulty?
    @State private var selectedCategory: PracticeParagraph.Category?

    var body: some View {
        VStack {
            // Header
            VStack(spacing: 8) {
                Text("Select Practice Text")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Choose a paragraph to practice reading aloud")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.top)
            
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
            .padding(.horizontal)

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
            .listStyle(PlainListStyle())
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

#Preview {
    ParagraphSelectorView(
        dataManager: ParagraphDataManager(),
        selectedParagraph: .constant(nil)
    ) { paragraph in
        print("Selected paragraph: \(paragraph.title)")
    }
}
