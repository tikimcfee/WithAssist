//
//  ChatClient.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/29/23.
//

import Foundation
import OpenAI

struct ChatRequest {
    var useUser = true
    var user: String = "lugo-core-conversation-query"
    
    var useTemperature = false
    var temperature: Double = 0.7
    
    var useTopProbabilityMass = false
    var topProbabilityMass: Double = 0.7
    
    var completions: Int = 1
    var maxTokens: Int = 4000
    
    var usePresencePenalty = false
    var presencePenalty: Double = 0.5
    
    var useFrequencyPenalty = false
    var frequencyPenalty: Double = 0.5
    
    var useLogitBias = false
    var logitBias: [String: Int]? = nil
    
    var chatModel: Model = .gpt4
}

extension ChatController {
    class SnapshotState: ObservableObject {
        @Published var current: Snapshot
        
        init(
            _ currentSnapshot: Snapshot
        ) {
            self.current = currentSnapshot
        }
    }
    
    class ParamState: ObservableObject {
        @Published var current: ChatRequest
        
        init(
            _ chatParams: ChatRequest = ChatRequest()
        ) {
            self.current = chatParams
        }
    }
}

class ChatController: ObservableObject {
    let openAI: OpenAI
    
    @Published var snapshot: SnapshotState
    @Published var chatParams: ParamState
    
    init(
        openAI: OpenAI,
        currentSnapshot: Snapshot = .empty
    ) {
        self.openAI = openAI
        self.snapshot = SnapshotState(currentSnapshot)
        self.chatParams = ParamState()
    }
    
    func addMessage(_ message: String) async {
        await addMessage(
            OpenAI.Chat(
                role: .user,
                content: message
            )
        )
    }
    
    func addMessage(_ chat: OpenAI.Chat) async {
        await modifySnapshot {
            $0.chatMessages.append(chat)
        }
        await updateSnapshotWithNewQuery()
    }
    
    func resetPrompt(to prompt: String) async {
        await resetPrompt(prompt)
        await updateSnapshotWithNewQuery()
    }
    
    private func performChatQuery() async throws -> OpenAI.ChatResult {
        let name = String(cString: __dispatch_queue_get_label(nil))
        print("--- Performing query on: \(name)")
        
        return try await openAI.chats(
            query: makeChatQuery(),
            timeoutInterval: 60.0 * 3
        )
    }
    
    func updateSnapshotWithNewQuery() async {
        do {
            let result = try await performChatQuery()
            let choice = makeChoice(result)
            
            await modifySnapshot {
                $0.results.append(result)
                if let choice {
                    $0.chatMessages.append(choice.message)
                }
            }
        } catch {
            print("[!!error \(#fileID)]: \(error)")
            await modifySnapshot {
                $0.errors.append(
                    AppError.wrapped(
                        String(describing: error),
                        UUID()
                    )
                )
            }
        }
    }
    
    func makeChoice(_ result: OpenAI.ChatResult) -> OpenAI.ChatResult.Choice? {
        result.choices?.first
    }
    
    private func modifySnapshot(_ snapshot: (inout Snapshot) -> Void) async {
        await MainActor.run {
            snapshot(&(self.snapshot.current))
        }
    }
}

extension ChatController {
    func resetPrompt(_ prompt: String) async {
        await MainActor.run { [snapshot] in
            snapshot.current.resetForNewPrompt(prompt)
        }
    }
    
    func makeChatQuery() -> OpenAI.ChatQuery {
        OpenAI.ChatQuery(
            model: chatParams.current.chatModel,
            messages: snapshot.current.chatMessages,
            temperature: chatParams.current.temperature,
            top_p: chatParams.current.topProbabilityMass,
            n: chatParams.current.completions,
            stream: false,
            max_tokens: chatParams.current.maxTokens,
            presence_penalty: chatParams.current.presencePenalty,
            frequency_penalty: chatParams.current.frequencyPenalty,
            logit_bias: chatParams.current.logitBias,
            user: chatParams.current.user
        )
    }
}
