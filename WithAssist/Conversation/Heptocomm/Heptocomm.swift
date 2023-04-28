//  WithAssist
//
//  Created on 4/12/23.
//  

import Foundation
import OpenAI

enum HeptocommMessageType {
    case assistantConversational
    case userConversational
    case assistantDefinition
    case userDefinition
}

protocol HeptocommMessage {
    var type: HeptocommMessageType { get set }
    var isTyped: Bool { get set }
    var content: String { get set }
}

struct Heptocomm {
    let controller: ChatController
    
    
}
