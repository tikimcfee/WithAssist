//
//  InteractionsView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/31/23.
//

import SwiftUI
import OpenAI
import Combine
func dismissKeys() {
    #if os(iOS)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    #endif
}

struct InteractionsView: View, Serialized {
    
    @ObservedObject var controller: ChatController
    @ObservedObject var state: ChatController.SnapshotState
    @StateObject var serializer = Serializer()
    
    @State var isLoading: Bool = false
    @State var showPrompt: Bool = false
    @State var showSettings: Bool = false
    @State var showErrors: Bool = false
    
    @State var approximateTokens: Int = 0
    @State var maxTokens: Int = 0
    @State var inputTokens: Int = 0
    
    init(controller: ChatController) {
        self.controller = controller
        self.state = controller.snapshotState
    }
    
    private var hasErrors: Bool {
        state.publishedSnapshot?.errors.isEmpty == false
    }
    
    var body: some View {
        chatView
            .overlay(loadingOverlayView())
            .overlay(updateTokenView())
            .onChange(of: state.publishedSnapshot) { _ in
                asyncIsolated {
                    await updateApproximateTokens()
                }
            }
            .onReceive(controller.paramState.$current) {
                maxTokens = $0.maxTokens
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    nameView()
                }
            }
    }
    
    @ViewBuilder
    var chatView: some View {
        VStack {
            ConversationView(
                controller: controller
            )
            .onTapGesture {
                dismissKeys()
            }
            
            tokenCountView
                .padding(.trailing)
            
            inputView()
                .padding()
                .disabled(isLoading || controller.needsToken)
        }
        #if os(iOS)
        .sheet(isPresented: $showPrompt) {
            promptInjectorView()
                .padding()
        }
        .sheet(isPresented: $showErrors) {
            errorView()
        }
        .popover(isPresented: $showSettings) {
            SettingsView(controller: controller)
        }
        #endif
        .toolbar {
            ToolbarItem {
                Button (action: {
                    showPrompt.toggle()
                }, label: {
                    Image(systemName: "person.2.gobackward")
                })
                #if os(macOS)
                .popover(isPresented: $showPrompt) {
                    promptInjectorView()
                        .frame(width: 600, height: 450)
                }
                #endif
            }
            
            ToolbarItem {
                Button (action: {
                    showSettings.toggle()
                }, label: {
                    Image(systemName: "gearshape.2.fill")
                })
                #if os(macOS)
                .popover(isPresented: $showSettings) {
                    SettingsView(controller: controller)
                        .frame(width: 450, height: 450)
                }
                #endif
            }
            
            if hasErrors {
                ToolbarItem(placement: .navigation) {
                    Button (action: {
                        showErrors.toggle()
                    }, label: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    })
                    #if os(macOS)
                    .popover(isPresented: $showErrors) {
                        errorView()
                            .frame(width: 600, height: 450)
                    }
                    #endif
                }
            }
        }
    }
    
    @ViewBuilder
    var rootView: some View {
        VStack {
            Button("Update token") {
                controller.setNeedsNewToken()
            }
            
            nameView()
            promptInjectorView()
            inputView()
            
            tokenCountView
            
            SettingsView(controller: controller)
            errorView()
        }
    }
    
    @ViewBuilder
    var tokenCountView: some View {
        Text("\(inputTokens)/\(maxTokens - approximateTokens) [Chat: \(approximateTokens)]")
            .frame(maxWidth: .infinity, alignment: .trailing)
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
    func promptInjectorView() -> some View {
        if let snapshot = state.publishedSnapshot {
            PromptInjectorView(
                draft: snapshot.results.first?.choices.first?.message?.content ?? "",
                didRequestSetPrompt: { updatedPromptText in
                    loadOnMain {
                        await controller.resetPrompt(to: updatedPromptText)
                    }
                }
            ).id(snapshot.id)
        }
    }
    
    @ViewBuilder
    func inputView() -> some View {
        ChatInputView(
            didRequestSend: { draft in
                loadOnMain {
                    await controller.addMessage(draft.content)
                }
            },
            didRequestResend: {
                loadOnMain {
                    await controller.retryFromCurrent()
                }
            },
            inputTokens: $inputTokens
        )
    }
    
    @MainActor
    @ViewBuilder
    func nameView() -> some View {
        if let snapshot = state.publishedSnapshot {
            TextField(
                snapshot.name,
                text: Binding<String>(
                    get: { snapshot.name },
                    set: { name in
                        asyncIsolated {
                            await controller.snapshotState.updateCurrent {
                                $0.name = name
                            }
                        }
                    }
                )
            )
        }
    }
    
    @ViewBuilder
    func errorView() -> some View {
        if let snapshot = state.publishedSnapshot, hasErrors {
            List {
                ForEach(snapshot.errors) { error in
                    Text(error.message)
                        .onLongPressGesture {
                            asyncIsolated {
                                await controller.removeError(error)
                            }
                        }
                }
            }
            .frame(maxHeight: 256.0)
        }
    }
    
    @ViewBuilder
    func loadingOverlayView() -> some View {
        if isLoading {
            ProgressView()
        }
    }
    
    func loadOnMain(_ action: @escaping () async -> Void) {
        asyncIsolated {
            await setIsLoading(isLoading: true)
            await action()
            await updateApproximateTokens()
            await setIsLoading(isLoading: false)
        }
    }
    
    func setIsLoading(isLoading target: Bool) async {
        await MainActor.run {
            isLoading = target
        }
    }
    
    func updateApproximateTokens() async {
        await MainActor.run {
            // 4 characters ~ 1 token
            approximateTokens = Int(Double(currentCharacterCount) / 4.0)
        }
    }
    
    var currentCharacterCount: Int {
        state.publishedSnapshot?.results.lazy.map {
            $0.choices.first?.message?.content.count ?? 0
        }.reduce(0, +)
        ?? 0
    }
}
