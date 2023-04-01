//
//  ChatClient.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/29/23.
//

import Foundation
import OpenAI
import Combine

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
    
    init(
        openAI: OpenAI
    ) {
        self.openAI = openAI
        self.snapshotState = SnapshotState()
        self.paramState = ParamState()
    }
    
    func saveManual() {
        snapshotState.saveAll()
    }
    
    func controlNewConversation() {
        snapshotState.startNewConversation()
    }
    
    func addMessage(
        _ message: String,
        _ role: OpenAI.Chat.Role = .user
    ) async {
        snapshotState.updateCurrent { current in
            current.chatMessages.append(
                OpenAI.Chat(
                    role: role,
                    content: message
                )
            )
            
            Task { [current] in
                var target = current
                await requestResponseFromGPT(&target)
            }
        }
    }
    
    func resetPrompt(to prompt: String) async {
        await snapshotState.updateCurrent { current in
            current.resetForNewPrompt(prompt)
            await requestResponseFromGPT(&current)
        }
    }
    
    func sendCurrentResponseToGPT(_ snapshot: Snapshot) async {
        do {
            _ = try await performChatQuery(using: snapshot)
        } catch {
            print("[!!error \(#fileID)]: \(error)")
        }
    }

    func requestResponseFromGPT(_ snapshot: inout Snapshot) async {
        do {
            let result = try await performChatQuery(using: snapshot)
            snapshot.results.append(result)
            
            if let choice = result.choices?.first {
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
    func performChatQuery(using current: Snapshot) async throws -> OpenAI.ChatResult {
//        guard let current = snapshotState.currentSnapshot else {
//            throw AppError.custom("no current snapshot to save")
//        }
        
        let name = String(cString: __dispatch_queue_get_label(nil))
        print("--- Performing query on: \(name)")
        
        return try await openAI.chats(
            query: makeChatQuery(current),
            timeoutInterval: 60.0 * 3
        )
    }
    
    func makeChatQuery(_ snapshot: Snapshot?) -> OpenAI.ChatQuery {
        OpenAI.ChatQuery(
            model: paramState.current.chatModel,
            messages: snapshot?.chatMessages ?? [],
            temperature: paramState.current.temperature,
            top_p: paramState.current.topProbabilityMass,
            n: paramState.current.completions,
            stream: false,
            max_tokens: paramState.current.maxTokens,
            presence_penalty: paramState.current.presencePenalty,
            frequency_penalty: paramState.current.frequencyPenalty,
            logit_bias: paramState.current.logitBias,
            user: paramState.current.user
        )
    }
}
