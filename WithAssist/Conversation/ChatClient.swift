//
//  ChatClient.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/29/23.
//

import Foundation
import OpenAI

struct ChatRequest {
    var useUser = false
    var user: String = "lugo-core-conversation-query"
    
    var useTemperature = false
    var temperature: Double = 0.7
    
    var useTopProbabilityMass = false
    var topProbabilityMass: Double = 0.7
    
    var completions: Int = 1
    var maxTokens: Int = 3072
    
    var usePresencePenalty = false
    var presencePenalty: Double = 0.5
    
    var useFrequencyPenalty = false
    var frequencyPenalty: Double = 0.5
    
    var useLogitBias = false
    var logitBias: [String: Int]? = nil
    
    var chatModel: Model = .gpt4
}

class Chat: ObservableObject {
    let openAI: OpenAI
        
    @Published var currentSnapshot: Snapshot
    @Published var chatParams: ChatRequest = ChatRequest()
    
    init(
        openAI: OpenAI,
        currentSnapshot: Snapshot = .empty
    ) {
        self.openAI = openAI
        self.currentSnapshot = currentSnapshot
    }
    
    func makeChatQuery() -> OpenAI.ChatQuery {
        OpenAI.ChatQuery(
            model: chatParams.chatModel,
            messages: currentSnapshot.chatMessages,
            temperature: chatParams.temperature,
            top_p: chatParams.topProbabilityMass,
            n: chatParams.completions,
            stream: false,
            max_tokens: chatParams.maxTokens,
            presence_penalty: chatParams.usePresencePenalty ? chatParams.presencePenalty : nil,
            frequency_penalty: chatParams.useFrequencyPenalty ? chatParams.frequencyPenalty : nil,
            logit_bias: chatParams.useLogitBias ? chatParams.logitBias : nil,
            user: chatParams.user
        )
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
        await updateSnapshot()
    }
    
    func resetPrompt(to prompt: String) async {
        await MainActor.run {
            self.currentSnapshot.resetForNewPrompt(prompt)
        }
        await updateSnapshot()
    }
    
    private func performChatQuery() async throws -> OpenAI.ChatResult {
        let name = String(cString: __dispatch_queue_get_label(nil))
        print("--- Performing query on: \(name)")
        
        return try await openAI.chats(
            query: makeChatQuery()
        )
    }
    
    func updateSnapshot() async {
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
            print(error)
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
            snapshot(&currentSnapshot)
        }
    }
}
