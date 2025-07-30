import SwiftUI

// PreferenceKey for FlexibleView height (must be outside generic type)
struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// FlexibleView for word wrapping
struct FlexibleView<Data: Collection, Content: View>: View {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Index, Data.Element) -> Content

    @State private var totalHeight = CGFloat.zero

    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        let dataArray = Array(data)
        return ZStack(alignment: Alignment(horizontal: alignment, vertical: .top)) {
            ForEach(Array(data.enumerated()), id: \.offset) { pair in
                let idx = pair.offset
                let item = pair.element
                content(data.index(data.startIndex, offsetBy: idx), item)
                    .padding([.horizontal, .vertical], 2)
                    .alignmentGuide(.leading, computeValue: { d in
                        if abs(width - d.width) > geometry.size.width {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if idx == dataArray.count - 1 {
                            width = 0 // Last item
                        } else {
                            width -= d.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { _ in
                        let result = height
                        if idx == dataArray.count - 1 {
                            height = 0 // Last item
                        }
                        return result
                    })
            }
        }
        .background(viewHeightReader($totalHeight))
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: ViewHeightKey.self, value: geometry.size.height)
        }
        .onPreferenceChange(ViewHeightKey.self) { value in
            binding.wrappedValue = value
        }
    }
}

struct TappableTextView: View {
    let paragraph: PracticeParagraph
    let wordAnalyses: [WordAnalysis]
    let onWordTap: (String) -> Void
    let scrollTargetIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(paragraph.title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 12)

            FlexibleView(
                data: Array(paragraph.words.enumerated()),
                spacing: 6,
                alignment: .leading
            ) { idx, pair in
                let (offset, word) = pair
                let analysis = wordAnalyses.first { $0.expectedIndex == offset }
                return Text(word)
                    .font(.title2)
                    .foregroundColor(textColor(for: analysis))
                    .background(backgroundColor(for: analysis))
                    .padding(analysis?.isCurrentWord == true ? 4 : 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(borderColor(for: analysis), lineWidth: analysis?.isCurrentWord == true ? 2 : 0)
                    )
                    .cornerRadius(4)
                    .onTapGesture { onWordTap(word) }
                    .id(offset)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private func backgroundColor(for analysis: WordAnalysis?) -> Color {
        guard let analysis = analysis else { return Color.clear }
        if analysis.isCorrect {
            // If it's a proper noun that was completed, use orange background
            if analysis.isProperNoun {
                return Color.orange.opacity(0.2)
            }
            return Color.green.opacity(0.2)
        } else if analysis.isMissing {
            return Color.red.opacity(0.3)
        } else if analysis.isMispronounced {
            return Color.orange.opacity(0.3)
        } else if analysis.isCurrentWord {
            return Color.blue.opacity(0.1)
        } else {
            return Color.clear
        }
    }

    private func textColor(for analysis: WordAnalysis?) -> Color {
        guard let analysis = analysis else { return .primary }
        if analysis.isCorrect {
            // If it's a proper noun that was completed, use orange text
            if analysis.isProperNoun {
                return .orange
            }
            return .green
        } else if analysis.isMissing || analysis.isMispronounced {
            return .red
        } else if analysis.isCurrentWord {
            return .blue
        } else {
            return .primary
        }
    }
    
    private func borderColor(for analysis: WordAnalysis?) -> Color {
        guard let analysis = analysis else { return Color.clear }
        if analysis.isCurrentWord {
            return .blue
        } else {
            return Color.clear
        }
    }
}

struct TranscriptionView: View {
    let transcribedText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Speech:")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 4) {
                if transcribedText.isEmpty {
                    Text("Start speaking...")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    displayWordsView
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .center)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var displayWordsView: some View {
        let words = transcribedText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        let displayWords = words.count <= 4 ? words : Array(words.suffix(4))
        
        return HStack(spacing: 8) {
            ForEach(Array(displayWords.enumerated()), id: \.offset) { index, word in
                let isLastWord = index == displayWords.count - 1
                Text(word)
                    .font(.title2)
                    .fontWeight(isLastWord ? .bold : .regular)
                    .foregroundColor(isLastWord ? .blue : .primary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(isLastWord ? Color.blue.opacity(0.1) : Color.clear)
                    .cornerRadius(6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
