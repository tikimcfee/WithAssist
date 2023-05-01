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
        _ message: String,
        _ role: Chat.Role = .user
    ) async {
        await snapshotState.updateCurrent { toUpdate in
            toUpdate.chatMessages.append(
                Chat(
                    role: role,
                    content: message
                )
            )
        }
        
//        await snapshotState.updateCurrent { toUpdate in
//            var targetCopy = toUpdate
//            await requestResponseFromGPT(&targetCopy)
//            toUpdate = targetCopy
//        }
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
    
    func removeMessage(_ toRemove: Chat) async {
        await snapshotState.updateCurrent { snapshot in
            guard let removeIndex = snapshot.chatMessages.firstIndex(where: {
                $0.id == toRemove.id
            }) else {
                print("[!! error: \(#function)] - cannot find message to remove")
                return
            }
            snapshot.chatMessages.remove(at: removeIndex)
        }
    }
    
    func update(message: Chat, to newMessage: Chat) async {
        await snapshotState.updateCurrent { snapshot in
            guard let updateIndex = snapshot.chatMessages.firstIndex(where: {
                $0.id == message.id
            }) else {
                print("[!! error: \(#function)] - cannot find message to update")
                return
            }
            
            snapshot.chatMessages[updateIndex] = newMessage
        }
    }
    
    func retryFromCurrent() async {
        await snapshotState.updateCurrent { current in
            await requestResponseFromGPT(&current)
        }
    }
    
    func resetPrompt(to prompt: String) async {
        await snapshotState.updateCurrent { current in
            current.resetForNewPrompt(prompt)
            await requestResponseFromGPT(&current)
        }
    }

    func requestResponseFromGPT(_ snapshot: inout Snapshot) async {
        do {
            let result = try await performChatQuery(using: snapshot)
            snapshot.results.append(result)
            
            if let choice = result.choices.first?.message {
                snapshot.chatMessages.append(choice)
            }
        } catch {
            print("[!!error \(#fileID)]: \(error)")
            snapshot.errors.append(AppError.wrapped(
                String(describing: error),
                UUID()
            ))
        }
    }
    
    func startStream() async {
        await snapshotState.updateCurrent { current in
            let query = makeChatQuery(current, stream: true)
            let stream = openAI.chatsStream(query: query)
            do {
                for try await chatResult in stream {
                    await snapshotState.updateCurrent {
                        $0.updateResultsFromStream(piece: chatResult)
                    }
                }
            } catch {
                print("[stream controller - error] \(error)")
            }
            
            print("[stream controller] stream complete")
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
        stream: Bool? = false
    ) -> ChatQuery {
        ChatQuery(
            model: paramState.current.chatModel,
            messages: snapshot?.chatMessages ?? [],
            temperature: paramState.current.temperature,
            topP: paramState.current.topProbabilityMass,
            n: paramState.current.completions,
            stream: stream,
            maxTokens: paramState.current.maxTokens,
            presencePenalty: paramState.current.presencePenalty,
            frequencyPenalty: paramState.current.frequencyPenalty,
            logitBias: paramState.current.logitBias,
            user: paramState.current.user
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
