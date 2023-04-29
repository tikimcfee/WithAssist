//
//  EditView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 4/28/23.
//

import Foundation
import RichTextKit
import OpenAI
import SwiftUI

struct EditView: View {
    let toEdit: Chat
    let onComplete: (Chat) -> Void
    let onDismiss: () -> Void
    
    @State var draft: NSAttributedString
    
    @StateObject private var context = {
        let context = RichTextContext()
        return context
    }()
    
    @Environment(\.colorScheme) var style: ColorScheme
    var foreground: NSColor {
        switch style {
        case .light: return .black
        case .dark: return .white
        @unknown default:
            return .black
        }
    }
    
    var background: NSColor {
        .clear
    }
    
    init(
        toEdit: Chat,
        onComplete: @escaping (Chat) -> Void,
        onDismiss: @escaping () -> Void) {
            self.toEdit = toEdit
            self.onComplete = onComplete
            self.onDismiss = onDismiss
            self._draft = State(wrappedValue: NSAttributedString(string: toEdit.content))
        }
    
    var body: some View {
        VStack(alignment: .trailing) {
            RichTextEditor(
                text: $draft,
                context: context,
                format: .plainText,
                viewConfiguration: { component in
                    component.setForegroundColor(to: foreground, at: draft.richTextRange)
                    component.setBackgroundColor(to: background, at: draft.richTextRange)
                }
            )
            .frame(maxHeight: 450)
            
            if !draft.string.isEmpty {
                Button("Save") {
                    onComplete(
                        toEdit.updatedContent(of: draft.string)
                    )
                }
            }
            
            Button("Cancel") {
                onDismiss()
            }
        }
        .padding(8)
        .background(Color.blue.opacity(0.1))
    }
}
