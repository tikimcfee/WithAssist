//
//  ContentView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/18/23.
//

import SwiftUI
import OpenAI

extension OpenAI.Chat: Identifiable {
    public var id: Int { hashValue }
}

struct ChatConversationView: View {
    @ObservedObject var client: AsyncClient.Chat
    @State var isLoading: Bool = false
    
    var body: some View {
        NavigationSplitView(
            sidebar: {
                
            },
            content: {
                mainInteractionsView(client.currentSnapshot)
                    .padding()
            },
            detail: {
                conversationView(client.currentSnapshot)
            }
        )
        .navigationSplitViewStyle(.balanced)
    }
    
    @ViewBuilder
    func waitingView() -> some View {
        Text("Waiting for a thing to happen")
    }
    
    @ViewBuilder
    func mainInteractionsView(_ snapshot: Snapshot) -> some View {
        VStack {
            promptInjectorView(snapshot)
            inputView()
            SettingsView(chat: client)
            
            if !snapshot.errors.isEmpty {
                errorView(snapshot: snapshot)
            }
        }
        .overlay(loadingOverlayView())
        .disabled(isLoading)
    }
    
    @ViewBuilder
    func loadingOverlayView() -> some View {
        if isLoading {
            ProgressView()
        } else {
            EmptyView()
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
        }
    }
    
    @ViewBuilder
    func conversationView(_ snapshot: Snapshot) -> some View {
        ScrollViewReader { proxy in
            List(snapshot.chatMessages.dropFirst()) { message in
                messageCell(message)
                    .tag(message.id)
            }
            .listStyle(.inset)
            .onChange(of: snapshot.chatMessages) { new in
                if let last = new.last {
                    print("Scroll to: \(last.id)")
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
    
    @ViewBuilder
    func inputView() -> some View {
        ChatInputView { draft in
            doAsync {
                await client.addMessage(draft.content)
            }
        }
    }
    
    @ViewBuilder
    func promptInjectorView(_ snapshot: Snapshot) -> some View {
        PromptInjectorView(
            draft: snapshot.chatMessages.first?.content ?? "",
            originalDraft: snapshot.chatMessages.first?.content ?? "",
            didRequestSetPrompt: { updatedPrompt in
                doAsync {
                    await client.resetPrompt(to: updatedPrompt)
                }
            }
        ).id(snapshot.hashValue)
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
    
    func doAsync(_ action: @escaping () async -> Void) {
        Task.detached(priority: .userInitiated) {
            await MainActor.run {
                isLoading = true
            }
            await action()
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct ChatInputView: View {
    @State var draft = Draft()
    let didRequestSend: (Draft) -> Void
    
    var body: some View {
        TextField("You", text: $draft.content, axis: .vertical)
            .lineLimit(6, reservesSpace: true)
            .onSubmit {
                guard draft.isReadyForSubmit else { return }
                didRequestSend(draft)
                draft = Draft()
            }
    }
}

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
                guard madeChange else { return }
                changePrompt = true
            }
            .alert(
                "Save new prompt?",
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
                    \(originalDraft)
                    
                    To:
                    \(draft)
                    """)
                }
            )
    }
}

struct ContentView_Previews: PreviewProvider {
    static let openAI = AsyncClient.makeAPIClient()
    
    static let snapshot = Snapshot(
        chatMessages: [
            .init(role: .system, content: "Hello, this is dog"),
            .init(role: .user, content: "Hello dog, good borks?"),
            .init(role: .assistant, content: "Very yes much always")
        ]
    )
    
    static let chat: AsyncClient.Chat = {
        AsyncClient.Chat(
            openAI: openAI,
            currentSnapshot: snapshot
        )
    }()
    
    static let client: AsyncClient = {
        let client = AsyncClient(
            chat: chat
        )
        
        return client
    }()
    
    static var previews: some View {
        ChatConversationView(
            client: client.chat
        )
    }
}
