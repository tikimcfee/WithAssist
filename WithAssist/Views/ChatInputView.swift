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
    @Binding var inputTokens: Int
    
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
                Button("Resend") {
                    didRequestResend()
                }
                .keyboardShortcut("r", modifiers: [.command, .option])
                
                Spacer()
                
                Button("Send message") {
                    Task {
                        let toSave = draft
                        await MainActor.run {
                            draft = NSAttributedString()
                        }
                        do {
                            try didRequestSend(Draft(content: toSave.string))
                        } catch {
                            print("[!! error: \(#function)] \(error)")
                            await MainActor.run {
                                draft = toSave
                            }
                        }
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
            
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
