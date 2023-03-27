//
//  WithAssist

/// Hello there assistant! I'm looking for some help writing up a small Swift and Metal library, as simply as I can, that adheres to the following:
///
/// - Uses Metal to render an instanced set of 2D planes of text that we'll call Glyphs.
/// - Uses Metal instancing techniques to draw the 2D planes as uniquely interactable objects in a standard scene-graph hierarchy.
/// - Can be plugged into a SceneKit Node in the Swift + iOS / macOS ecosystem so its rendering is embeddable and portable.

/// The class below is the shell I would you to start autocompleting. Ask me questions as you need to build abstractions.
///
import Metal
import MetalKit
import OpenAI

private let OPENAI_API_KEY = "your-key-here"

class AsyncClient {
    private static let defaultClient = makeAPIClient()
    private static let defaultChat = Chat(
        openAI: defaultClient
    )
    
    var client: OpenAI = makeAPIClient()
    var chat: Chat
    
    init(
        client: OpenAI = defaultClient,
        chat: Chat = defaultChat
    ) {
        self.client = client
        self.chat = chat
    }
    
    static func makeAPIClient() -> OpenAI {
        let client = OpenAI(apiToken: OPENAI_API_KEY)
        
        return client
    }
}

enum AppError: Identifiable {
    case wrapped(Error, UUID)
    
    var id: UUID {
        switch self {
        case .wrapped(_, let id):
            return id
        }
    }
    
    var message: String {
        switch self {
        case .wrapped(let error, _):
            return error.localizedDescription
        }
    }
}

struct Snapshot {
    var chatMessages: [OpenAI.Chat] = []
    var errors: [AppError] = []
    var results: [OpenAI.ChatResult] = []
}

struct Draft: Equatable, Hashable {
    var content: String = ""
    
    var isReadyForSubmit: Bool {
        !content.isEmpty
    }
}

extension AsyncClient {
    
    class Chat: ObservableObject {
        let openAI: OpenAI
        var chatModel: Model

        @Published var currentSnapshot: Snapshot
        
        @Published var useTemperature = false
        @Published var temperature: Double = 0.7
        
        @Published var useTopProbabilityMass = false
        @Published var topProbabilityMass: Double = 0.7
        
        @Published var completions: Int = 1
        @Published var maxTokens: Int = 2048
        
        @Published var usePresencePenalty = false
        @Published var presencePenalty: Double = 0.5
        
        @Published var useFrequencyPenalty = false
        @Published var frequencyPenalty: Double = 0.5
        
        @Published var useLogitBias = false
        @Published var logitBias: [String: Int]? = nil
        
        init(
            openAI: OpenAI,
            chatModel: Model = .gpt3_5Turbo,
            currentSnapshot: Snapshot = Snapshot()
        ) {
            self.openAI = openAI
            self.chatModel = chatModel
            self.currentSnapshot = currentSnapshot
        }
        
        var chatQuery: OpenAI.ChatQuery {
            OpenAI.ChatQuery(
                model: chatModel,
                messages: currentSnapshot.chatMessages,
                temperature: temperature,
                top_p: topProbabilityMass,
                n: completions,
                stream: false,
                max_tokens: maxTokens,
                presence_penalty: usePresencePenalty ? presencePenalty : nil,
                frequency_penalty: useFrequencyPenalty ? frequencyPenalty : nil,
                logit_bias: useLogitBias ? logitBias : nil,
                user: "lugo-core-conversation-query"
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
            await setSnapshot(
                Snapshot(
                    chatMessages: [
                        OpenAI.Chat(
                            role: .system,
                            content: prompt
                        )
                    ]
                )
            )
            await updateSnapshot()
        }
        
        private func performChatQuery() async throws -> OpenAI.ChatResult {
            let name = String(cString: __dispatch_queue_get_label(nil))
            print("--- Performing query on: \(name)")
            
            return try await openAI.chats(query: chatQuery)
        }
        
        private func updateSnapshot() async {
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
                        AppError.wrapped(error, UUID())
                    )
                }
                
            }
        }
        
        func makeChoice(_ result: OpenAI.ChatResult) -> OpenAI.ChatResult.Choice? {
            result.choices.first
        }
        
        private func setSnapshot(_ snapshot: Snapshot) async {
            await MainActor.run {
                self.currentSnapshot = snapshot
            }
        }
        
        private func modifySnapshot(_ snapshot: (inout Snapshot) -> Void) async {
            await MainActor.run {
                snapshot(&currentSnapshot)
            }
        }
    }
}
