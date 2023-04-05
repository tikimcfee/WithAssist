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
        
        await snapshotState.updateCurrent { toUpdate in
            var targetCopy = toUpdate
            await requestResponseFromGPT(&targetCopy)
            toUpdate = targetCopy
        }
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
            
            if let choice = result.choices.first {
                snapshot.chatMessages.append(choice.message)
            }
        } catch {
            print("[!!error \(#fileID)]: \(error)")
            snapshot.errors.append(AppError.wrapped(
                String(describing: error),
                UUID()
            ))
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
            result.choices.first?.message.content
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
    
    func makeChatQuery(_ snapshot: Snapshot?) -> ChatQuery {
        
        let candidateMessage = (snapshot?.chatMessages ?? [])
        var contextWindow: [Chat] = []
        var runningTokenCount = 0
        for message in candidateMessage.reversed() {
            // TODO: Replace with actual tokenization and token count someday.
            let tokenEstimate = message.content.count / 4
            if tokenEstimate + runningTokenCount < 3000 {
                contextWindow.append(message)
                runningTokenCount += message.content.count
            } else {
                print("[ChatClient] Limiting Context Window.")
                break // Early stop.
            }
        }
        print("[ChatClient] Took \(contextWindow.count)/\(candidateMessage.count) of the previous messages.")
        contextWindow.reverse()
        
        return ChatQuery(
            model: paramState.current.chatModel,
            messages: contextWindow,
            temperature: paramState.current.temperature,
            topP: paramState.current.topProbabilityMass,
            n: paramState.current.completions,
            stream: false,
            maxTokens: paramState.current.maxTokens - runningTokenCount,
            presencePenalty: paramState.current.presencePenalty,
            frequencyPenalty: paramState.current.frequencyPenalty,
            logitBias: paramState.current.logitBias,
            user: paramState.current.user
        )
    }
}
