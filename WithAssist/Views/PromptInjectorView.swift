//
//  PromptInjectorView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/31/23.
//

import SwiftUI
import RichTextKit

struct PromptInjectorView: View {
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
    
    @State private var draft: NSAttributedString
    let originalDraft: String
    let didRequestSetPrompt: (String) -> Void
    
    @State var changePrompt = false
    
    @StateObject private var context = {
        let context = RichTextContext()
        return context
    }()
    
    init(
        draft: String,
        didRequestSetPrompt: @escaping (String) -> Void
    ) {
        self._draft = State(wrappedValue: NSAttributedString(string: draft))
        self.originalDraft = draft
        self.didRequestSetPrompt = didRequestSetPrompt
    }
    
    var madeChange: Bool {
        draft.string != originalDraft
    }
    
    var body: some View {
        VStack(alignment: .trailing) {
            mainTextField
            
            Button("Reset Prompt", role: .destructive) {
                changePrompt = true
            }
            .keyboardShortcut("r", modifiers: .command)
        }
    }
    
    @ViewBuilder
    var mainTextField: some View {
        RichTextEditor(
            text: $draft,
            context: context,
            format: .plainText,
            viewConfiguration: { component in
                component.setForegroundColor(to: foreground, at: draft.richTextRange)
                component.setBackgroundColor(to: background, at: draft.richTextRange)
            }
        )
        .frame(maxHeight: 600)
        .alert(
            "Reset this conversation and save new prompt?",
            isPresented: $changePrompt,
            actions: {
                Button("Yes", role: .destructive) {
                    defer { changePrompt = false }
                    
                    guard !draft.string.isEmpty else { return }
                    didRequestSetPrompt(draft.string)
                }
                
                Button("No", role: .cancel) {
                    changePrompt = false
                }
            },
            message: {
                Text("""
                From:
                \(originalDraft.count) characters
                
                To:
                \(draft.string.count) characters
                """)
            }
        )
    }
}

