//
//  ChatClient.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/29/23.
//

import Foundation
import OpenAI
import Combine

let OPENAI_API_KEY = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
let CLAUDE_API_KEY = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"]

protocol GlobalStoreReader {
    var snapshotStorage: FileStorageSerial { get }
}

extension GlobalStoreReader {
    var snapshotStorage: FileStorageSerial {
        GlobalFileStore.shared.snapshotStorage
    }
}

class GlobalFileStore {
    public static let shared = GlobalFileStore()
    
    let snapshotStorage = FileStorageSerial()
    
    private init() {
        
    }
}

class ChatController: ObservableObject {
    let openAI: OpenAI
    
    
    // Testing claude w/ Anthropic
    let claude = ClaudeClient(apiKey: CLAUDE_API_KEY!)
    
    enum MessageTarget {
        case openAI
        case anthropic
    }
    var messageTarget: MessageTarget = .anthropic
    
    private(set) var bag = Set<AnyCancellable>()
    
    @Published var snapshotState: SnapshotState
    @Published var paramState: ParamState
    @Published var isLoading: Bool = false
    @Published private(set) var needsToken: Bool = true
    
    var apiToken: String {
        get {
            openAI.configuration.token
        }
        set {
            openAI.configuration.token = newValue
            needsToken = false
        }
    }
    
    init(
        openAI: OpenAI
    ) {
        self.openAI = openAI
        self.snapshotState = SnapshotState()
        self.paramState = ParamState()
        
        if OPENAI_API_KEY != nil {
            needsToken = false
        }
        
        snapshotState.$publishedSnapshot.sink { _ in
            self.objectWillChange.send()
        }.store(in: &bag)
        
        snapshotState.$allSnapshots.sink { _ in
            self.objectWillChange.send()
        }.store(in: &bag)
        
        snapshotState.$currentIndex.sink { _ in
            self.objectWillChange.send()
        }.store(in: &bag)
    }
    
    func saveManual() {
        snapshotState.saveAll()
    }
    
    func controlNewConversation() {
        snapshotState.startNewConversation()
    }
    
    func setNeedsNewToken() {
        needsToken = true
    }
    
    func addMessage(
        _ message: String,
        _ role: Chat.Role = .user
    ) async {
        await snapshotState.updateCurrent { toUpdate in
            toUpdate.results.append(
                message.wrapAsContentOfUserResult(model: paramState.current.chatModel)
            )
        }
        
        await startStream()
    }
    
    func removeError(_ toRemove: AppError) async {
        await snapshotState.updateCurrent { current in
            let id = toRemove.id
            current.errors.removeAll(where: { id == $0.id })
        }
    }
    
    func removeSnapshot(_ toRemove: Snapshot) async {
        await snapshotState.update { state in
            guard let removeIndex = state.allSnapshots.list.firstIndex(where: {
                $0.id == toRemove.id
            }) else {
                print("[!! error: \(#function)] - cannot find message to remove")
                return
            }
            state.allSnapshots.isSaved = false
            state.allSnapshots.list.remove(at: removeIndex)
        }
    }
    
    func removeResult(
        _ toRemove: ChatResult
    ) async {
        await snapshotState.updateCurrent { snapshot in
            snapshot.results[toRemove.id] = nil
        }
    }
    
    func updateResult(
        _ newResult: ChatResult
    ) async {
        await snapshotState.updateCurrent { snapshot in
            snapshot.results[newResult.id] = newResult
        }
    }
    
    func retryFromCurrent() async {
        await startStream()
    }
    
    func resetPrompt(to prompt: String) async {
        await snapshotState.updateCurrent { current in
            current.resetForNewPrompt(
                prompt.wrapAsContentOfUserResult(model: paramState.current.chatModel)
            )
            await requestResponseFromGPT(&current)
        }
    }

    func requestResponseFromGPT(_ snapshot: inout Snapshot) async {
        do {
            let result = try await performChatQuery(using: snapshot)
            snapshot.results.append(result)
        } catch {
            print("[!!error \(#fileID)]: \(error)")
            snapshot.errors.append(AppError.wrapped(
                String(describing: error),
                UUID()
            ))
        }
    }
    
    func startStream() async {
        print("(\(#file):\(#function)) - starting stream to [\(messageTarget)]!")
        
        switch messageTarget {
        case .anthropic:
            await doClaudeStream()
            
        case .openAI:
            await doOpenAIStream()
        }
    }
    
    func loadController() {
        snapshotState.load()
    }
}

extension ChatController {
    func performChatQuery(using current: Snapshot) async throws -> ChatResult {
        let name = String(cString: __dispatch_queue_get_label(nil))
        print("--- Performing query on: \(name)")
                
        let result: ChatResult
        switch messageTarget {
        case .anthropic:
            result = try await doClaudeRequest(using: current)
            
        case .openAI:
            result = try await doOpenAIRequest(using: current)
        }
        
        logResult(result)
        return result
    }
    
    func doOpenAIStream() async {
        guard let snapshot = snapshotState.publishedSnapshot else {
            return
        }
        
        let query = makeChatQuery(snapshot, stream: true)
        do {
            let stream = openAI.chatsStream(query: query)
            for try await chatResult in stream {
                await snapshotState.updateCurrent { current in
                    print("updating: \(chatResult.id)")
                    print("updating: \(chatResult.firstMessage?.content ?? "~x")")
                    current.updateResultsFromStream(piece: chatResult)
                }
            }
        } catch {
            print("[stream controller - error] \(error)")
        }
        
        print("[stream controller] stream complete")
    }
    
    func doClaudeStream() async {
        guard let snapshot = snapshotState.publishedSnapshot else {
            return
        }
        
        do {
            let query = makeClaudeQuery(snapshot, stream: true)
            let stream = claude.asyncCompletionStream(request: query)
            
            var choice = ChatResult.Choice(
                index: 0,
                message: Chat(role: .assistant, content: ""),
                finishReason: "stop"
            )
            
            var chatResult = ChatResult(
                id: UUID().uuidString,
                object: "claude-api-result",
                created: Date.now.timeIntervalSince1970,
                model: .__anthropic_claude,
                choices: [choice],
                usage: ChatResult.Usage()
            )
            
            for try await queryItem in stream {
                choice.message = Chat(role: .assistant, content: queryItem.completion)
                chatResult.choices[0] = choice
                await snapshotState.updateCurrent { current in
                    print("updating: \(chatResult.id)")
                    print("updating: \(chatResult.firstMessage?.content ?? "~x")")
                    current.results[chatResult.id] = chatResult
                }
            }
        } catch {
            print("[stream controller - error] \(error)")
        }
        print("[stream controller] stream complete")
    }
    
    func doOpenAIRequest(using current: Snapshot) async throws -> ChatResult {
        try await openAI.chats(
            query: makeChatQuery(current)
        )
    }
    
    func doClaudeRequest(using current: Snapshot) async throws -> ChatResult {
        let query = makeClaudeQuery(current, stream: false)
        let stream = claude.asyncCompletionStream(request: query)
        
        var result = ChatResult(
            id: UUID().uuidString,
            object: "claude-api-result",
            created: Date.now.timeIntervalSince1970,
            model: .__anthropic_claude,
            choices: [],
            usage: ChatResult.Usage()
        )

        for try await queryItem in stream {
            result.upsertChoice(
                newChoice: ChatResult.Choice(
                    index: 0,
                    message: Chat(
                        role: .assistant,
                        content: queryItem.completion
                    ),
                    finishReason: "stop"
                )
            )
        }
        
        return result
    }
    
    func logResult(_ result: ChatResult) {
        Task {
            let firstMessage =
                result.choices.first?.message?.content
                ?? "<no response message>"
            
            print(
            """

            Received response:
            ----------------------------------------------------------------
            \(firstMessage)
            ----------------------------------------------------------------

            """)
        }
    }
    
    func collectContextChatWindow(
        _ snapshot: Snapshot?,
        stream: Bool = false
    ) -> ([Chat], Int) {
        let limit = ModelTokenLimit[paramState.current.chatModel, default: FallbackTokenLimit]
        let candidateMessages = snapshot.firstMessageList
        var contextWindow: [Chat] = []
        var runningTokenCount = 0
        for message in candidateMessages.reversed() {
            // TODO: Replace with actual tokenization and token count someday.
            let tokenEstimate = message.content.approximateTokens
            if tokenEstimate + runningTokenCount < limit {
                contextWindow.append(message)
                runningTokenCount += message.content.count
            } else {
                print("[ChatClient] Limiting Context Window.")
                break // Early stop.
            }
        }
        print("[ChatClient] Took \(contextWindow.count)/\(candidateMessages.count) of the previous messages.")
        return (contextWindow.reversed(), runningTokenCount)
    }
    
    func makeClaudeQuery(
        _ snapshot: Snapshot?,
        stream: Bool = false
    ) -> ClaudeClient.Request {
        let (
            contextWindow,
            runningTokenCount
        ) = collectContextChatWindow(
            snapshot,
            stream: stream
        )
        
        var finalPrompt = ""
        for chat in contextWindow {
            switch chat.role {
            case .assistant: finalPrompt.append(CLAUDE_ASSISTANT_PROMPT)
            case .system: finalPrompt.append(CLAUDE_ASSISTANT_PROMPT)
            case .user: finalPrompt.append(CLAUDE_HUMAN_PROMPT)
            }
            finalPrompt.append(chat.content)
        }
        
        // Append an assistant prompt as safety, it's a requirement of the API
        if contextWindow.last?.role != .assistant {
            finalPrompt.append(CLAUDE_ASSISTANT_PROMPT)
        }
        
        return ClaudeClient.Request(
            prompt: finalPrompt,
            stream: stream,
            maxTokensToSample: paramState.current.maxTokens - runningTokenCount,
            temperature: Float(paramState.current.temperature)
        )
    }
    
    func makeChatQuery(
        _ snapshot: Snapshot?,
        stream: Bool = false
    ) -> ChatQuery {
        let (
            contextWindow,
            runningTokenCount
        ) = collectContextChatWindow(
            snapshot,
            stream: stream
        )
        
        return ChatQuery(
            model: paramState.current.chatModel,
            messages: contextWindow,
            temperature: paramState.current.temperature,
            topP: paramState.current.topProbabilityMass,
            n: paramState.current.completions,
            stream: stream,
            maxTokens: paramState.current.maxTokens - runningTokenCount,
            presencePenalty: paramState.current.presencePenalty,
            frequencyPenalty: paramState.current.frequencyPenalty,
            logitBias: paramState.current.logitBias,
            user: paramState.current.user
        )
    }
}

extension Optional where Wrapped == Snapshot {
    var firstMessageList: [Chat] {
        self?.results.compactMap {
            $0.firstMessage
        } ?? []
    }
}

extension String {
    func wrapAsContentOfUserResult(
        model: Model
    ) -> ChatResult {
        ChatResult(
            id: UUID().uuidString,
            object: "chat.user-message",
            created: Date.now.timeIntervalSince1970,
            model: model,
            choices: [
                .init(
                    index: 0,
                    message: Chat(role: .user, content: self),
                    finishReason: nil
                )
            ],
            usage: ChatResult.Usage()
        )
    }
}

