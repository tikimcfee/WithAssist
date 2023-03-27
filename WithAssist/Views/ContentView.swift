//
//  ContentView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/18/23.
//

import SwiftUI
import OpenAI

struct ChatConversationView: View {
    @ObservedObject var client: AsyncClient.Chat
    @State var isLoading: Bool = false
    
    var body: some View {
        makeBodyView()
            .padding()
    }
    
    @ViewBuilder
    func makeBodyView() -> some View {
        snapshotView(client.currentSnapshot)
    }
    
    @ViewBuilder
    func waitingView() -> some View {
        Text("Waiting for a thing to happen")
    }
    
    @ViewBuilder
    func snapshotView(_ snapshot: Snapshot) -> some View {
        HStack {
            mainInteractionsView(snapshot)
            conversationView(snapshot)
        }
    }
    
    @ViewBuilder
    func mainInteractionsView(_ snapshot: Snapshot) -> some View {
        VStack(alignment: .leading){
            prompInjectorView(
                snapshot.chatMessages.first(where: {
                    $0.role == OpenAI.Chat.Role.system.rawValue
                })?.content ?? ""
            )
            Divider()
            
            inputView()
            Divider()
            
            SettingsView(chat: client)
            Divider()
            
            errorView(snapshot: snapshot)
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
                .frame(maxWidth: 600, alignment: .leading)
        }
    }
    
    @ViewBuilder
    func conversationView(_ snapshot: Snapshot) -> some View {
        VStack(alignment: .leading) {
            Text("Conversation")
            
            ScrollViewReader { proxy in
                List {
                    ForEach(snapshot.chatMessages.dropFirst()) { message in
                        messageCell(message)
                            .tag(message.id)
                    }
                }
                .onChange(of: snapshot.chatMessages) { new in
                    if let last = new.last {
                        print("Scroll to: \(last.id)")
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
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
    func prompInjectorView(_ prompt: String) -> some View {
        PromptInjectorView(
            draft: Draft(
                content: prompt
            )
        ) { draft in
            doAsync {
                await client.resetPrompt(to: draft.content)
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

struct SettingsView: View {
    @ObservedObject var chat: AsyncClient.Chat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
//            HStack {
//                Toggle("Logit Bias", isOn: $chat.useLogitBias)
//            }
            ToggleSlider(
                name: "Tokens",
                use: .constant(true),
                value: .init(
                    get: { Double(chat.maxTokens) },
                    set: { chat.maxTokens = Int($0) }
                ),
                range: 0.0...4095
            )
            
            ToggleSlider(
                name: "Probability Mass (top-p)",
                use: $chat.useTopProbabilityMass,
                value: $chat.topProbabilityMass,
                range: 0.0...1.0
            )
            
            ToggleSlider(
                name: "Temperature",
                use: $chat.useTemperature,
                value: $chat.temperature,
                range: 0.0...2.0
            )
            
            ToggleSlider(
                name: "Frequency Penalty",
                use: $chat.useFrequencyPenalty,
                value: $chat.frequencyPenalty,
                range: -2.0...2.0
            )
            
            ToggleSlider(
                name: "Presence Penalty",
                use: $chat.usePresencePenalty,
                value: $chat.presencePenalty,
                range: -2.0...2.0
            )
        }
    }
}

struct ToggleSlider: View {
    let name: String
    @Binding var use: Bool
    @Binding var value: Double
    var range: ClosedRange<Double>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(name, isOn: $use)
            if use {
                Slider(
                    value: $value,
                    in: range,
                    label: {
                        Text("\(value, format: .number)")
                    },
                    minimumValueLabel: {
                        Text("\(range.lowerBound, format: .number)")
                    },
                    maximumValueLabel: {
                        Text("\(range.upperBound, format: .number)")
                    }
                )
            }
        }
        .padding(
            [.bottom], use ? 12.0 : 8.0
        )
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
    @State var changePrompt = false
    
    private var originalDraft: Draft
    let didRequestSetPrompt: (Draft) -> Void
    
    var madeChange: Bool {
        draft != originalDraft
    }
    
    init(
        draft: Draft,
        didRequestSetPrompt: @escaping (Draft) -> Void
    ) {
        self.draft = draft
        self.originalDraft = draft
        self.didRequestSetPrompt = didRequestSetPrompt
    }
    
    var body: some View {
        VStack(alignment: .leading){
            TextField("Prompt:", text: $draft.content, axis: .vertical)
                .lineLimit(5, reservesSpace: true)
                .textFieldStyle(.squareBorder)
                .onSubmit {
                    guard madeChange else { return }
                    changePrompt = true
                }
        }
        .alert(
            "Save new prompt?",
            isPresented: $changePrompt,
            actions: {
                Button("Yes", role: .destructive) {
                    defer { changePrompt = false }
                    
                    guard draft.isReadyForSubmit else { return }
                    didRequestSetPrompt(draft)
                }
                
                Button("No", role: .cancel) {
                    changePrompt = false
                }
            },
            message: {
                Text("""
                From:
                \(originalDraft.content)

                To:
                \(draft.content)
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
