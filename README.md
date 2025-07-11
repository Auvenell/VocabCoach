# VocabCoach - iOS Reading & Pronunciation Trainer

VocabCoach is an iOS mobile app designed to help users improve their spoken English vocabulary and fluency through interactive reading practice with real-time pronunciation feedback.

## Features

### 🎯 Core Functionality
- **Live Speech Recognition**: Uses Apple's Speech framework for real-time transcription
- **Real-time Feedback**: Highlights mispronounced words and missing words as you read
- **Interactive Text**: Tap any word to hear its pronunciation using text-to-speech
- **Progress Tracking**: Visual progress indicator showing accuracy percentage
- **Multiple Difficulty Levels**: Beginner, Intermediate, and Advanced texts
- **Various Categories**: General, Business, Academic, and Casual content

### 🎨 User Interface
- **Clean, Modern Design**: Intuitive SwiftUI interface
- **Visual Feedback**: Color-coded word highlighting (green for correct, red for errors, orange for mispronunciations)
- **Confidence Indicator**: Shows speech recognition confidence level
- **Responsive Controls**: Start/Stop reading buttons with clear visual states

### 📚 Practice Content
- **Curated Paragraphs**: 8 sample texts across different difficulty levels
- **Word-by-Word Analysis**: Detailed feedback on each word's pronunciation
- **Audio Feedback**: Spoken guidance and encouragement

## Technical Implementation

### Architecture
- **SwiftUI**: Modern declarative UI framework
- **MVVM Pattern**: Clean separation of concerns
- **ObservableObject**: Reactive data binding
- **Combine**: Reactive programming for state management

### Key Components
1. **SpeechRecognitionManager**: Handles live speech transcription
2. **TextToSpeechManager**: Provides pronunciation feedback
3. **PracticeView**: Main interface for reading practice
4. **TappableTextView**: Interactive text display with highlighting
5. **ParagraphDataManager**: Manages practice content

### Permissions Required
- **Microphone Access**: For speech recognition
- **Speech Recognition**: For transcription services

## Setup Instructions

### Prerequisites
- Xcode 14.0 or later
- iOS 16.0 or later
- Physical iOS device (speech recognition works best on device)

### Installation
1. Clone or download the project
2. Open `VocabCoach.xcodeproj` in Xcode
3. Select your target device
4. Build and run the project

### First Run
1. Grant microphone and speech recognition permissions when prompted
2. Tap "Start Practice" to begin
3. Select a practice paragraph from the available options
4. Tap "Start Reading" and begin reading aloud

## Usage Guide

### Getting Started
1. **Select Text**: Choose from beginner, intermediate, or advanced paragraphs
2. **Start Reading**: Tap the "Start Reading" button to begin
3. **Read Aloud**: Speak clearly into your device's microphone
4. **Get Feedback**: Watch for real-time highlighting and feedback
5. **Tap Words**: Tap any word to hear its pronunciation
6. **Review Progress**: Check your accuracy score and progress

### Understanding Feedback
- **Green Words**: Correctly pronounced
- **Red Words**: Missing or significantly mispronounced
- **Orange Words**: Slightly mispronounced
- **Progress Bar**: Overall accuracy percentage

### Tips for Best Results
- Speak clearly and at a moderate pace
- Ensure a quiet environment
- Hold the device close to your mouth
- Practice regularly with different difficulty levels

## Sample Practice Texts

### Beginner Level
- "A Day at the Park" - Casual conversation
- "My Morning Routine" - Daily activities

### Intermediate Level
- "Technology in Education" - Academic content
- "Healthy Living" - General wellness
- "Business Communication" - Professional skills

### Advanced Level
- "Climate Change Impact" - Scientific topics
- "Artificial Intelligence Ethics" - Complex concepts
- "Global Market Dynamics" - Business analysis

## Future Enhancements

Potential features for future versions:
- User progress history and statistics
- Custom paragraph creation
- Multiple language support
- Advanced pronunciation scoring
- Social features and leaderboards
- Offline mode with pre-downloaded content

## Technical Notes

### Speech Recognition Accuracy
- Works best with clear pronunciation
- May vary based on accent and speaking speed
- Requires internet connection for processing

### Performance Considerations
- Optimized for real-time processing
- Minimal battery impact during use
- Efficient memory management for long sessions

## Support

For technical issues or feature requests, please refer to the project documentation or contact the development team.

---

**VocabCoach** - Making English pronunciation practice engaging and effective! 🎤📚 