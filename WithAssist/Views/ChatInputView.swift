//
//  ChatInputView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/31/23.
//

import SwiftUI
import OpenAI
import Combine

#if os(iOS)
typealias NSColor = UIColor
#endif

class DraftWrap: ObservableObject {
    @Published var draft = NSAttributedString()
}

struct ChatInputView: View, Serialized {
    let didRequestSend: (Draft) throws -> Void
    let didRequestResend: () -> Void
    @Binding var inputTokens: Int
    
    @FocusState var focused
    @State var text: String = ""
    
    var body: some View {
        editorBody
            .border(Color.gray, width: 1)
            .onChange(of: text) { new in
                inputTokens = text.count / 4
            }
    }
    
    @ViewBuilder
    var editorBody: some View {
        VStack(alignment: .trailing, spacing: 0) {
            TextEditor(text: $text)
                .focused($focused)
                .frame(height: 100)
            
            HStack {
                Button("Resend") {
                    focused = false
                    didRequestResend()
                }
                .keyboardShortcut("r", modifiers: [.command, .option])
                
                Button("Send message") {
                    let backup = text
                    do {
                        focused = false
                        text = ""
                        try didRequestSend(Draft(content: backup))
                    } catch {
                        print("[!! error: \(#function)] \(error)")
                        text = backup
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal)
            .padding(.vertical, 2)
            
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
