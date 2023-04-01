//
//  ConversationView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/31/23.
//

import SwiftUI
import OpenAI

struct ConversationView: View {
    let snapshot: Snapshot
    
    var body: some View {
        ScrollViewReader { proxy in
            List(snapshot.chatMessages.dropFirst()) { message in
                messageCell(message)
                    .tag(message.id)
            }
            .listStyle(.inset)
            .onChange(of: snapshot.results) { _ in
                if let last = snapshot.chatMessages.last {
                    print("Scroll to: \(last.id)")
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
    
    @ViewBuilder
    func messageCell(_ message: OpenAI.Chat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(message.role)
                .italic()
                .fontWeight(.light)
                .font(.caption)
            
            Text(message.content)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .border(Color.gray.opacity(0.33), width: 1)
        
    }
}
