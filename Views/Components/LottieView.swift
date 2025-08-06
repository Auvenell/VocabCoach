import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    let animationName: String
    let loopMode: LottieLoopMode
    let animationSpeed: CGFloat
    let contentMode: UIView.ContentMode
    
    init(
        animationName: String,
        loopMode: LottieLoopMode = .loop,
        animationSpeed: CGFloat = 1.0,
        contentMode: UIView.ContentMode = .scaleAspectFit
    ) {
        self.animationName = animationName
        self.loopMode = loopMode
        self.animationSpeed = animationSpeed
        self.contentMode = contentMode
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let animationView = LottieAnimationView()
        
        if let animation = LottieAnimation.named(animationName) {
            animationView.animation = animation
            animationView.contentMode = contentMode
            animationView.loopMode = loopMode
            animationView.animationSpeed = animationSpeed
            animationView.play()
        }
        
        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.topAnchor.constraint(equalTo: view.topAnchor),
            animationView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            animationView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update logic if needed
    }
}

// MARK: - Animation Manager
class LottieAnimationManager: ObservableObject {
    static let shared = LottieAnimationManager()
    
    @Published var isPlaying = false
    
    private init() {}
    
    func playAnimation(_ animationName: String) {
        isPlaying = true
        // Animation logic will be handled by individual views
    }
    
    func stopAnimation() {
        isPlaying = false
    }
} 