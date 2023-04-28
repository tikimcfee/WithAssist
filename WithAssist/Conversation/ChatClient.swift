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
    
    func ___testEmbedding(
        _ draft: Draft
    ) async {
        do {
            let embeddings = try await openAI.embeddings(
                query: EmbeddingsQuery(
                    model: paramState.current.chatModel,
                    input: draft.content
                )
            )
            print("[embedding] \(embeddings.data.count) top levels found")
            if let first = embeddings.data.first {
                print("[embedding [0]] \(first.index), [\(first.embedding.count)]: \(first.object)")
            }
            
            trySaveEmbedding(embeddings)
        } catch {
            print("[!! error] \(error)")
        }
    }
    
    private func trySaveEmbedding(_ embedding: EmbeddingsResult) {
        GlobalFileSelector.requestSystemUrl(for: "embedding result", completion: { target in
            switch target {
            case .some(let directory):
                do {
                    guard directory.hasDirectoryPath else { throw AppError.custom("must select directory [\(directory)]") }
                    // lol get the raw value as cache or something ...
                    try FileStorageSerial.shared.save(
                        embedding,
                        to: .custom("embedding-autosave-\(UUID()).json")
                    )
                } catch {
                    print(error)
                }
                
            default:
                print("[embedding] no save target")
            }
        })
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
        ChatQuery(
            model: paramState.current.chatModel,
            messages: snapshot?.chatMessages ?? [],
            temperature: paramState.current.temperature,
            topP: paramState.current.topProbabilityMass,
            n: paramState.current.completions,
            stream: false,
            stop: paramState.current.stop,
            maxTokens: paramState.current.maxTokens,
            presencePenalty: paramState.current.presencePenalty,
            frequencyPenalty: paramState.current.frequencyPenalty,
            logitBias: paramState.current.logitBias,
            user: paramState.current.user
        )
    }
}
