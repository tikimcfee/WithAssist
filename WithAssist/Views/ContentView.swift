//
//  ContentView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/18/23.
//

import SwiftUI
import OpenAI
import Combine

struct ChatConversationView: View {
    @ObservedObject var client: Chat
    @State var isLoading: Bool = false
    
    let requestCurrentStateSave: () -> Void
    let requestNewConversation: () -> Void
    
    var body: some View {
        NavigationSplitView(
            sidebar: {
                SnapshotListView(
                    currentSnapshot: $client.currentSnapshot
                )
            },
            content: {
                mainInteractionsView(client.currentSnapshot)
                    .padding()
            },
            detail: {
                conversationView(client.currentSnapshot)
                    .toolbar {
                        ToolbarItem(placement:  .primaryAction) {
                            newConversationView
                        }
                    }
            }
        )
        .navigationSplitViewStyle(.balanced)
    }
    
    var newConversationView: some View {
        Button(
            action: {
                requestNewConversation()
            },
            label: {
                Label("New Conversation", systemImage: "plus.circle")
                    .labelStyle(.titleAndIcon)
            }
        )
    }
    
    @ViewBuilder
    func waitingView() -> some View {
        Text("Waiting for a thing to happen")
    }
    
    @ViewBuilder
    func mainInteractionsView(_ snapshot: Snapshot) -> some View {
        VStack {
            nameView()
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
    
    struct ConversationView: View {
        let snapshot: Snapshot
        
        var body: some View {
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
    
    @ViewBuilder
    func conversationView(_ snapshot: Snapshot) -> some View {
        ConversationView(snapshot: snapshot)
    }
    
    @ViewBuilder
    func nameView() -> some View {
        TextField(
            client.currentSnapshot.name,
            text: Binding<String>(
                get: { client.currentSnapshot.name },
                set: { client.currentSnapshot.name = $0 }
            )
        )
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
            requestNewConversation()
            
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

struct ContentView_Previews: PreviewProvider {
    static let userSettingsStorage =
        CodableFileStorage<SnapshotStore>(
            storageObject: .empty,
            appFile: .defaultSnapshot
        )
    
    static let openAI = ClientStore.makeAPIClient()
    
    static let snapshot = Snapshot(
        chatMessages: [
            .init(role: .system, content: "Hello, this is dog"),
            .init(role: .user, content: "Hello dog, good borks?"),
            .init(role: .assistant, content: "Very yes much always")
        ]
    )
    
    static let chat: Chat = {
        Chat(
            openAI: openAI,
            currentSnapshot: snapshot
        )
    }()
    
    static let client: ClientStore = {
        let client = ClientStore(
            chat: chat
        )
        
        return client
    }()
    
    static var previews: some View {
        ChatConversationView(
            client: client.chat,
            requestCurrentStateSave: { },
            requestNewConversation: { }
        )
        .environmentObject(userSettingsStorage)

    }
}
