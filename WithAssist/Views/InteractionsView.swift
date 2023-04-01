//
//  InteractionsView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/31/23.
//

import SwiftUI
import OpenAI
import Combine

struct InteractionsView: View {
    let isLoading: Bool
    let snapshot: Snapshot
    let controller: ChatController
    
    var body: some View {
        VStack {
            nameView()
            promptInjectorView(snapshot)
            inputView()
            
            SettingsView(chat: controller)
            
            if !snapshot.errors.isEmpty {
                errorView(snapshot: snapshot)
            }
        }
        .overlay(loadingOverlayView())
        .disabled(isLoading)
    }
    
    @ViewBuilder
    func promptInjectorView(_ snapshot: Snapshot) -> some View {
        PromptInjectorView(
            draft: snapshot.chatMessages.first?.content ?? "",
            originalDraft: snapshot.chatMessages.first?.content ?? "",
            didRequestSetPrompt: { updatedPromptText in
                Task {
                    await controller.resetPrompt(to: updatedPromptText)
                }
            }
        ).id(snapshot.hashValue)
    }
    
    @ViewBuilder
    func inputView() -> some View {
        ChatInputView(
            didRequestSend: { draft in
                Task {
                    await controller.addMessage(draft.content)
                }
            },
            didRequestResend: { draft in
                Task {
                    await controller.snapshotState.usingCurrent {
                        await controller.sendCurrentResponseToGPT($0)
                    }
                }
            }
        )
    }
    
    @MainActor @ViewBuilder
    func nameView() -> some View {
        TextField(
            controller.snapshotState.currentSnapshot?.name ?? "<oopsie>",
            text: Binding<String>(
                get: { controller.snapshotState.currentSnapshot?.name ?? "" },
                set: { controller.snapshotState.currentSnapshot?.name = $0 }
            )
        )
    }
    
    @ViewBuilder
    func errorView(snapshot: Snapshot) -> some View {
        List {
            ForEach(snapshot.errors) { error in
                Text(error.message)
            }
        }
        .frame(maxHeight: 256.0)
    }
    
    @ViewBuilder
    func loadingOverlayView() -> some View {
        if isLoading {
            ProgressView()
        } else {
            EmptyView()
        }
    }
}
