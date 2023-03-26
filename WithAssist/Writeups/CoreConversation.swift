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
    private static let defaultChat = Chat(openAI: defaultClient)
    
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

struct Draft {
    var content: String = ""
    
    var isReadyForSubmit: Bool {
        !content.isEmpty
    }
}

extension AsyncClient {
    actor Chat: ObservableObject {
        
        let openAI: OpenAI
        var chatModel: Model
        var currentSnapshot: Snapshot
        
        let continueConversation: Bool = true
        
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
                messages: currentSnapshot.chatMessages
            )
        }
        
        func addMessage(_ message: String) async -> Snapshot {
            return await addMessage(
                OpenAI.Chat(
                    role: .user,
                    content: message
                )
            )
        }
        
        func addMessage(_ chat: OpenAI.Chat) async -> Snapshot {
            currentSnapshot.chatMessages.append(chat)
            return await updateSnapshot()
        }
        
        func resetPrompt(to prompt: String) async -> Snapshot {
            currentSnapshot = Snapshot(
                chatMessages: [
                    OpenAI.Chat(
                        role: .system,
                        content: prompt
                    )
                ]
            )
            return await updateSnapshot()
        }
        
        func updateSnapshot() async -> Snapshot {
            do {
                let result = try await openAI.chats(query: chatQuery)
                currentSnapshot.results.append(result)
                
                if continueConversation, let choice = makeChoice(result) {
                    currentSnapshot.chatMessages.append(
                        OpenAI.Chat(
                            role: choice.message.role,
                            content: choice.message.content
                        )
                    )
                }
            } catch {
                currentSnapshot.errors.append(
                    AppError.wrapped(error, UUID())
                )
                print(error)
            }
            
            return currentSnapshot
        }
        
        func makeChoice(_ result: OpenAI.ChatResult) -> OpenAI.ChatResult.Choice? {
            result.choices.first
        }
    }
}
