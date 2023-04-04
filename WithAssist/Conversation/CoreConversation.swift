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

extension OpenAI.Chat: Identifiable {
    public var id: Int { hashValue }
}

class ClientStore {
    var client: OpenAI
    var chat: ChatController
    
    init(
        client: OpenAI = defaultClient,
        chat: ChatController = defaultChat
    ) {
        self.client = client
        self.chat = chat
    }
}

extension ClientStore {
    private static let defaultClient = makeAPIClient()
    
    private static let defaultChat = {
        ChatController(
            openAI: defaultClient
        )
    }()
    
    static func makeAPIClient() -> OpenAI {
        let client = OpenAI(apiToken: OPENAI_API_KEY ?? "")
        
        return client
    }
}

struct Draft: Equatable, Hashable {
    var content: String = ""
    
    var isReadyForSubmit: Bool {
        !content.isEmpty
    }
}
