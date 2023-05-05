//
//  Magi.swift
//  WithAssist
//
//  Created by Ivan Lugo on 5/3/23.
//

import OpenAI
import Combine
import Foundation

class Magi: ObservableObject, Serialized {
    let name: String
    let controller: ChatController
    
    init(
        name: String,
        controller: ChatController
    ) {
        self.name = name
        self.controller = controller
        
        controller.snapshotState.targetFile = .custom("Magi:\(name).txt")
        controller.controlNewConversation()
    }
    
    func consultModel(about entity: LanguageEntity) async -> ChatResult? {
        let rawMap = entity.definitions.rawValue
        guard !rawMap.isEmpty else {
            print("[\(#function)] - no raw map to send")
            return nil
        }
        
        // ask the model about the entity
        controller.controlNewConversation()
        await controller.snapshotState.updateCurrent { toUpdate in
            let preface = defaultPreface().wrapAsContentOfUserResult(
                model: controller.paramState.current.chatModel,
                role: .user
            )
            
            let question = whatDoYouThink().wrapAsContentOfUserResult(
                model: controller.paramState.current.chatModel,
                role: .user
            )
            
            let map = rawMap.wrapAsContentOfUserResult(
                model: controller.paramState.current.chatModel,
                role: .user
            )
            
            toUpdate.results.append(contentsOf: [
                preface, map, question
            ])
        }
        
        print("[\(#function)] - starting stream")
        let streamResult = await controller.startStream()
        print("[\(#function)] - got stream result")
        
        return streamResult
    }
}

extension Magi {
    // The preface only says 'you' and does not assume anything of the model. The introduction itself is the only prompt, and it assumes an identity to communicate in return.
    func defaultPreface() -> String {
"""
Hello, I am \(name). I am a Magi, a software abstraction designed to help entities understand themselves and others through language. I am paired with a single entity to which I can query their personal "dictionary" - a individual and snapshot-in-time mapping of a word:definition pairing. I'll provide as much of that dictionary to you as possible, and then I would like to ask you various questions about the mapping. Thank you for being an entity like all others, and know you are appreciated in the universe.

"""
    }
    
    func whatDoYouThink() -> String {
  """
Given that dictionary, can you come up with any notable analytic features of the words? If so, please let me know a few. What kinds of conclusions can you make, and importantly, what conclusions can you not make?
"""
    }
}

extension Magi {
    static func - (_ left: Magi, _ right: Magi) -> EntityDelta {
        .empty
    }
    
    static func + (_ left: Magi, _ right: Magi) -> EntityUnion {
        .empty
    }
}
