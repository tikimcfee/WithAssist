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

enum AppError: Identifiable, Codable, Equatable, Hashable {
    case wrapped(String, UUID)
    
    var id: UUID {
        switch self {
        case .wrapped(_, let id):
            return id
        }
    }
    
    var message: String {
        switch self {
        case .wrapped(let message, _):
            return message
        }
    }
}



struct Draft: Equatable, Hashable {
    var content: String = ""
    
    var isReadyForSubmit: Bool {
        !content.isEmpty
    }
}
