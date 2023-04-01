//
//  ChatInputView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/31/23.
//

import SwiftUI
import OpenAI
import Combine

struct ChatInputView: View {
    @State var draft = Draft()
    let didRequestSend: (Draft) -> Void
    let didRequestResend: (Draft) -> Void
    
    var body: some View {
        VStack(alignment: .trailing) {
            TextField("You", text: $draft.content, axis: .vertical)
                .lineLimit(6, reservesSpace: true)
                .onSubmit {
                    guard draft.isReadyForSubmit else { return }
                    didRequestSend(draft)
                    draft = Draft()
                }
            
            if draft.isReadyForSubmit {
                Button("Resend") {
                    didRequestResend(draft)
                }
            }
        }
    }
}
