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
        _ message: String
    ) async {
        await snapshotState.updateCurrent { toUpdate in
            toUpdate.results.append(
                message.wrapAsContentOfUserResult(model: paramState.current.chatModel)
            )
        }
        
        await startStream()
    }
    
    func appendResult(
        _ message: ChatResult
    ) async {
        await snapshotState.updateCurrent { toUpdate in
            toUpdate.results.append(message)
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
        await snapshotState.updateCurrent { current in
            await requestResponseFromGPT(&current)
        }
    }
    
    func resetPrompt(to prompt: String) async {
        await snapshotState.updateCurrent { current in
            current.resetForNewPrompt(
                prompt.wrapAsContentOfUserResult(model: paramState.current.chatModel)
            )
        }
        
        await startStream()
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
        guard let snapshot = snapshotState.publishedSnapshot else {
            return
        }
        let query = makeChatQuery(snapshot, stream: true)
        do {
            let stream = openAI.chatsStream(query: query)
            print("[stream controller] Starting stream...")
            for try await chatResult in stream {
                await snapshotState.updateCurrent { current in
//                    print("updating: \(chatResult.id)")
//                    print("updating: \(chatResult.firstMessage?.content ?? "~x")")
                    current.updateResultsFromStream(piece: chatResult)
                }
            }
            print("[stream controller] Stream complete.")
        } catch {
            print("[stream controller - error] \(error)")
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
        
        let result = try await openAI.chats(
            query: makeChatQuery(current)
        )
        
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
        
        return result
    }
    
    func makeChatQuery(
        _ snapshot: Snapshot?,
        stream: Bool = false
    ) -> ChatQuery {
        
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
        contextWindow.reverse()
        
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
        model: Model,
        role: Chat.Role = .user
    ) -> ChatResult {
        ChatResult(
            id: UUID().uuidString,
            object: "chat.user-message",
            created: Date.now.timeIntervalSince1970,
            model: model,
            choices: [
                .init(
                    index: 0,
                    message: Chat(role: role, content: self),
                    finishReason: nil
                )
            ],
            usage: ChatResult.Usage()
        )
    }
}

class ChatStreamController {
    var chatController: ChatController
    var llmAPI: OpenAI
    
    init(chatController: ChatController, llmAPI: OpenAI) {
        self.chatController = chatController
        self.llmAPI = llmAPI
    }
    
    func startStream(
        from query: ChatQuery
    ) async {
        let stream = llmAPI.chatsStream(query: query)
        do {
            for try await chatResult in stream {
                await chatController.snapshotState.updateCurrent {
                    $0.updateResultsFromStream(piece: chatResult)
                }
            }
        } catch {
            print("[stream controller - error] \(error)")
        }
        
        print("[stream controller] stream complete")
    }
}
