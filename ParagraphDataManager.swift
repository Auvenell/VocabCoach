import Foundation

class ParagraphDataManager: ObservableObject {
    @Published var paragraphs: [PracticeParagraph] = []
    
    init() {
        loadSampleParagraphs()
    }
    
    private func loadSampleParagraphs() {
        paragraphs = [
            // Beginner paragraphs
            PracticeParagraph(
                title: "A Day at the Park",
                text: "The sun was shining brightly in the sky. Children were playing on the swings and slides. Birds were singing in the trees. It was a perfect day for a picnic.",
                difficulty: .beginner,
                category: .casual
            ),
            
            PracticeParagraph(
                title: "My Morning Routine",
                text: "I wake up at seven o'clock every morning. First, I brush my teeth and wash my face. Then I eat breakfast with my family. After that, I get dressed and go to work.",
                difficulty: .beginner,
                category: .general
            ),
            
            // Intermediate paragraphs
            PracticeParagraph(
                title: "Technology in Education",
                text: "Modern technology has transformed the way we learn. Students can now access information instantly through the internet. Digital tools help teachers create engaging lessons. However, it's important to balance technology with traditional learning methods.",
                difficulty: .intermediate,
                category: .academic
            ),
            
            PracticeParagraph(
                title: "Healthy Living",
                text: "Maintaining a healthy lifestyle is essential for long-term well-being and requires both dedication and consistency. It’s not about quick fixes or extreme routines, but rather building sustainable habits that support your body and mind every day. One of the cornerstones of a healthy lifestyle is regular physical activity. Exercise does more than just tone muscles it boosts cardiovascular health, enhances flexibility, and releases endorphins that improve mood and reduce stress. Whether it’s walking, swimming, strength training, or yoga, consistent movement plays a vital role in physical and mental resilience. Equally important is proper nutrition. Fueling the body with a balanced diet rich in whole foods provides essential vitamins, minerals, and nutrients that help the body function efficiently. A diet high in fruits, vegetables, lean proteins, and whole grains not only supports physical health but can also positively influence energy levels, focus, and even emotional well-being. Sleep is another crucial pillar of health that is often overlooked. Getting sufficient and quality rest each night allows the body to recover, strengthens the immune system, and helps regulate mood and cognitive function. Chronic sleep deprivation, on the other hand, can lead to a host of physical and mental health issues over time.",
                difficulty: .intermediate,
                category: .general
            ),
            
            PracticeParagraph(
                title: "Business Communication",
                text: "Effective communication is essential in the business world. Clear emails and presentations help convey your message professionally. Active listening skills improve team collaboration. Regular feedback ensures everyone stays aligned with company goals.",
                difficulty: .intermediate,
                category: .business
            ),
            
            // Advanced paragraphs
            PracticeParagraph(
                title: "Climate Change Impact",
                text: "Climate change represents one of the most pressing challenges of our time. Rising global temperatures affect ecosystems worldwide, leading to biodiversity loss and extreme weather events. Scientists emphasize the urgent need for sustainable practices and renewable energy adoption. International cooperation is crucial for implementing effective solutions.",
                difficulty: .advanced,
                category: .academic
            ),
            
            PracticeParagraph(
                title: "Artificial Intelligence Ethics",
                text: "The rapid advancement of artificial intelligence raises profound ethical questions about privacy, employment, and decision-making autonomy. As AI systems become more sophisticated, we must carefully consider their societal implications. Transparent algorithms and responsible development practices are essential for building trust. Balancing innovation with ethical considerations requires ongoing dialogue among stakeholders.",
                difficulty: .advanced,
                category: .academic
            ),
            
            PracticeParagraph(
                title: "Global Market Dynamics",
                text: "Contemporary global markets exhibit unprecedented interconnectedness through digital platforms and international trade networks. Economic fluctuations in one region can trigger cascading effects across multiple sectors worldwide. Investors must navigate complex regulatory environments while adapting to rapidly evolving technological landscapes. Strategic planning requires comprehensive analysis of both local and global market conditions.",
                difficulty: .advanced,
                category: .business
            )
        ]
    }
    
    func getParagraphs(for difficulty: PracticeParagraph.Difficulty? = nil, category: PracticeParagraph.Category? = nil) -> [PracticeParagraph] {
        var filteredParagraphs = paragraphs
        
        if let difficulty = difficulty {
            filteredParagraphs = filteredParagraphs.filter { $0.difficulty == difficulty }
        }
        
        if let category = category {
            filteredParagraphs = filteredParagraphs.filter { $0.category == category }
        }
        
        return filteredParagraphs
    }
    
    func getRandomParagraph(difficulty: PracticeParagraph.Difficulty? = nil, category: PracticeParagraph.Category? = nil) -> PracticeParagraph? {
        let filteredParagraphs = getParagraphs(for: difficulty, category: category)
        return filteredParagraphs.randomElement()
    }
} 
