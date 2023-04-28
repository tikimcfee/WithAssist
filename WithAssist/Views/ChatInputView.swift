//
//  ChatInputView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/31/23.
//

import SwiftUI
import OpenAI
import Combine
import RichTextKit

#if os(iOS)
typealias NSColor = UIColor
#endif

struct ChatInputView: View {
    let didRequestSend: (Draft) throws -> Void
    let didRequestResend: () -> Void
    let didRequestDraft: (Draft) throws -> Void
    @Binding var inputTokens: Int
    var inputOnly: Bool = false
    
    @State var draft = NSAttributedString()
    
    @StateObject private var context = {
        let context = RichTextContext()
        return context
    }()
    
    var body: some View {
        editorBody
            .border(Color.gray, width: 1)
            .onChange(of: draft.string) { new in
                inputTokens = draft.string.count / 4
            }
    }
    
    @ViewBuilder
    var editorBody: some View {
        VStack(alignment: .trailing) {
            RichTextEditor(
                text: Binding(
                    get: { draft },
                    set: {
                        draft = $0
                        inputTokens = draft.string.count
                    }
                ),
                context: context,
                format: .plainText,
                viewConfiguration: { component in
                    component.setForegroundColor(to: foreground, at: draft.richTextRange)
                    component.setBackgroundColor(to: background, at: draft.richTextRange)
                }
            )
            .frame(height: 200)
            
            Divider()
            
            HStack {
                if !inputOnly {
                    Button("Resend 􀱗") {
                        didRequestResend()
                    }
                }
                
                Spacer()
                
                if !inputOnly {
                    Button("Test Embedding") {
                        do {
                            try didRequestDraft(Draft(content: draft.string))
                            draft = NSAttributedString()
                        } catch {
                            print("[!! error: \(#function)] \(error)")
                        }
                    }
                }
                
                Spacer()
                
                Button("Send message") {
                    do {
                        try didRequestSend(Draft(content: draft.string))
                        draft = NSAttributedString()
                    } catch {
                        print("[!! error: \(#function)] \(error)")
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
            
            Divider()
        }
    }
    
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
    
}
