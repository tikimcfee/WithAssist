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

struct ChatInputView: View {
    let didRequestSend: (Draft) -> Void
    let didRequestResend: () -> Void
    
    @State var draft = NSAttributedString()
    
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
            .frame(height: 200)
            
            Divider()
            
            HStack {
                Button("Resend 􀱗") {
                    didRequestResend()
                }
                .keyboardShortcut("r", modifiers: [.command, .option])
                
                Spacer()
                
                Button("Send message") {
                    didRequestSend(
                        Draft(content: draft.string)
                    )
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
            
            Divider()
        }
    }
}
