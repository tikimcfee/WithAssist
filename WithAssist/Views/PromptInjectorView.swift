//
//  PromptInjectorView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/31/23.
//

import SwiftUI

struct PromptInjectorView: View {
    @State var draft: String
    @State var changePrompt = false
    
    let originalDraft: String
    let didRequestSetPrompt: (String) -> Void
    
    var madeChange: Bool {
        draft != originalDraft
    }
    
    var body: some View {
        mainTextField
    }
    
    @ViewBuilder
    var mainTextField: some View {
        TextField("Prompt", text: $draft, axis: .vertical)
            .lineLimit(6, reservesSpace: true)
            .onSubmit {
                changePrompt = true
            }
            .alert(
                "Reset this conversation and save new prompt?",
                isPresented: $changePrompt,
                actions: {
                    Button("Yes", role: .destructive) {
                        defer { changePrompt = false }
                        
                        guard !draft.isEmpty else { return }
                        didRequestSetPrompt(draft)
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
                    \(draft.count) characters
                    """)
                }
            )
    }
}

