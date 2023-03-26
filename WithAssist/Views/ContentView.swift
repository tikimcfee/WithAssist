//
//  ContentView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/18/23.
//

import SwiftUI
import OpenAI

struct ChatConversationView: View {
    let client: AsyncClient
    
    enum Presentation {
        case waiting
        case ready(Snapshot)
    }
    
    @State var presentation: Presentation = .waiting
    @State var refreshTask: Task<(), Never>?
    @State var hoveredCell: OpenAI.Chat?
    
    var body: some View {
        makeBodyView()
            .padding()
    }
    
    @ViewBuilder
    func makeBodyView() -> some View {
        switch presentation {
        case .waiting:
            waitingView()
            
        case .ready(let snapshot):
            snapshotView(snapshot)
        }
    }
    
    @ViewBuilder
    func waitingView() -> some View {
        Text("Waiting for a thing to happen")
            .task {
                let current = await client.chat.currentSnapshot
                self.presentation = .ready(current)
            }
    }
    
    @ViewBuilder
    func snapshotView(_ snapshot: Snapshot) -> some View {
        ZStack(alignment: .top) {
            HStack {
                VStack(alignment: .leading){
                    Text("Conversation View")
                    List {
                        ForEach(snapshot.chatMessages) { message in
                            messageCell(message)
                        }
                    }
                    
                    Divider()
                    inputView()
                    
                    Divider()
                    prompInjectorView()
                }

                errorView(snapshot: snapshot)
            }
        }
        
        EmptyView()
    }
    
    @ViewBuilder
    func messageCell(_ message: OpenAI.Chat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(message.role)
                .italic()
                .fontWeight(.light)
                .font(.caption)
            Text(message.content)
                .frame(maxWidth: 600, alignment: .leading)
        }
        .padding()
        .background(
            hoveredCell == message
                ? Color.gray.opacity(0.3)
                : Color.clear
        )
        .onHover(perform: { isHovering in
            if isHovering {
                hoveredCell = message
            }
        })
    }
    
    @ViewBuilder
    func inputView() -> some View {
        ChatInputView { draft in
            Task {
                let nextSnapshot = await client.chat.addMessage(draft.content)
                await update(nextSnapshot)
            }
        }
    }
    
    @ViewBuilder
    func prompInjectorView() -> some View {
        PromptInjectorView { draft in
            Task {
                let nextSnapshot = await client.chat.resetPrompt(to: draft.content)
                await update(nextSnapshot)
            }
        }
    }
    
    
    @ViewBuilder
    func errorView(snapshot: Snapshot) -> some View {
        List {
            ForEach(snapshot.errors) { error in
                Text(error.message)
            }
        }
    }
    
    @ViewBuilder
    func refreshView() -> some View {
        Button(
            action: { updatePresentation() },
            label: {
                Text("Refresh")
            }
        )
    }
    
    func updatePresentation() {
        refreshTask?.cancel()
        refreshTask = Task(priority: .userInitiated) {
            let nextSnapshot = await client.chat.updateSnapshot()
            await update(nextSnapshot)
        }
    }
    
    func update(_ snapshot: Snapshot) async {
        await MainActor.run {
            self.presentation = .ready(snapshot)
        }
    }
}

extension OpenAI.Chat: Identifiable, Hashable, Equatable {
    public var id: Int { hashValue }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.role)
        hasher.combine(self.content)
    }
    
    public static func == (left: OpenAI.Chat, right: OpenAI.Chat) -> Bool {
        left.role == right.role
        && left.content == right.content
    }
}

struct ChatInputView: View {
    @State var draft = Draft()
    let didRequestSend: (Draft) -> Void
    
    var body: some View {
        VStack(alignment: .leading){
            TextField("You:", text: $draft.content, axis: .vertical)
                .lineLimit(5, reservesSpace: true)
                .textFieldStyle(.squareBorder)
                .onSubmit {
                    guard draft.isReadyForSubmit else { return }
                    didRequestSend(draft)
                    draft = Draft()
                }
        }
    }
}

struct PromptInjectorView: View {
    @State var draft = Draft()
    let didRequestSetPrompt: (Draft) -> Void
    
    var body: some View {
        VStack(alignment: .leading){
            TextField("Prompt:", text: $draft.content, axis: .vertical)
                .lineLimit(5, reservesSpace: true)
                .textFieldStyle(.squareBorder)
                .onSubmit {
                    guard draft.isReadyForSubmit else { return }
                    didRequestSetPrompt(draft)
                    draft = Draft()
                }
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static let snapshot = Snapshot(
        chatMessages: [
            .init(role: .system, content: "Hello, this is dog"),
            .init(role: .user, content: "Hello dog, good borks?"),
            .init(role: .assistant, content: "Very yes much always")
        ]
    )
    
    static let client: AsyncClient = {
        let openAI = AsyncClient.makeAPIClient()
        
        let client = AsyncClient(
            chat: AsyncClient.Chat(
                openAI: openAI,
                currentSnapshot: snapshot
            )
        )
        
        return client
    }()
    
    static var previews: some View {
        ChatConversationView(
            client: client,
            presentation: .ready(snapshot)
        )
    }
}
