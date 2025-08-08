//
//  CustomTextEditor.swift
//  VocabCoach
//
//  Created by Aunik Paul on 8/6/25.
//

import SwiftUI
import UIKit

// MARK: - Custom TextEditor with Cursor Position Preservation

struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let isDisabled: Bool
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = UIColor.systemGray6
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.isEditable = !isDisabled
        textView.isScrollEnabled = true
        textView.text = text.isEmpty ? placeholder : text
        textView.textColor = text.isEmpty ? UIColor.placeholderText : UIColor.label
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        // Only update text if it's different and preserve cursor position
        if textView.text != text {
            let currentPosition = textView.selectedTextRange
            textView.text = text.isEmpty ? placeholder : text
            textView.textColor = text.isEmpty ? UIColor.placeholderText : UIColor.label
            
            // Restore cursor position if it was valid
            if let position = currentPosition {
                textView.selectedTextRange = position
            }
        }
        
        textView.isEditable = !isDisabled
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextEditor
        
        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            let newText = textView.text == parent.placeholder ? "" : (textView.text ?? "")
            parent.text = newText
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.text == parent.placeholder {
                textView.text = ""
                textView.textColor = UIColor.label
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            if (textView.text ?? "").isEmpty {
                textView.text = parent.placeholder
                textView.textColor = UIColor.placeholderText
            }
        }
    }
}