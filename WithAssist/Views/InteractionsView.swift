//
//  InteractionsView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/31/23.
//

import SwiftUI
import OpenAI
import Combine

struct InteractionsView: View, Serialized {
    
    @ObservedObject var controller: ChatController
    @ObservedObject var state: ChatController.SnapshotState
    @StateObject var serializer = Serializer()
    @State var isLoading: Bool = false
    
    init(controller: ChatController) {
        self.controller = controller
        self.state = controller.snapshotState
    }
    
    private var snapshot: Snapshot? {
        controller.snapshotState.currentSnapshot
    }
    
    var body: some View {
        VStack {
            Button("Update token") {
                controller.setNeedsNewToken()
            }
            nameView()
            if let snapshot {
                promptInjectorView(snapshot)
            }
            inputView()
            
            SettingsView(chat: controller)
            
            if let snapshot {
                if !snapshot.errors.isEmpty {
                    errorView(snapshot: snapshot)
                }
            }
        }
        .disabled(isLoading || controller.needsToken)
        .overlay(loadingOverlayView())
        .overlay(updateTokenView())
    }
    
    @ViewBuilder
    func updateTokenView() -> some View {
        if controller.needsToken {
            VStack {
                Text("API token not set")
                TextField("Token", text: Binding(
                    get: { controller.apiToken },
                    set: { controller.apiToken = $0 })
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
    }
    
    @ViewBuilder
    func promptInjectorView(_ snapshot: Snapshot) -> some View {
        PromptInjectorView(
            draft: snapshot.chatMessages.first?.content ?? "",
            originalDraft: snapshot.chatMessages.first?.content ?? "",
            didRequestSetPrompt: { updatedPromptText in
                asyncMain {
                    await setIsLoading(isLoading: true)
                    await controller.resetPrompt(to: updatedPromptText)
                    await setIsLoading(isLoading: false)
                }
            }
        ).id(snapshot.hashValue)
    }
    
    @ViewBuilder
    func inputView() -> some View {
        ChatInputView(
            didRequestSend: { draft in
                asyncMain {
                    await setIsLoading(isLoading: true)
                    await controller.addMessage(draft.content)
                    await setIsLoading(isLoading: false)
                }
            },
            didRequestResend: {
                asyncMain {
                    await setIsLoading(isLoading: true)
                    await controller.retryFromCurrent()
                    await setIsLoading(isLoading: false)
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
                set: { name in
                    asyncMain {
                        await controller.snapshotState.updateCurrent {
                            $0.name = name
                        }
                    }
                }
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
        }
    }
    
    func setIsLoading(isLoading target: Bool) async {
        await MainActor.run {
            isLoading = target
        }
    }
}
