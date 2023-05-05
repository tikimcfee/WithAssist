//
//  Magi.swift
//  WithAssist
//
//  Created by Ivan Lugo on 5/3/23.
//

import OpenAI
import Combine
import Foundation

actor MagiEntityStage {
    @Published var magi: Magi
    @Published var entity: LanguageEntity
    
    @Published var observations: [ChatResult] = []
    
    private var saveToken: Any?
    private lazy var fileStore = FileStorageSerial()
    private var consultTask: Task<Void, Error>?
    
    init(
        magi: Magi,
        entity: LanguageEntity
    ) async {
        self.magi = magi
        self.entity = entity
        
        self.saveToken = $entity
            .removeDuplicates()
            .dropFirst()
            .handleEvents(receiveOutput: saveEntity(_:))
            .sink(receiveValue: communicateChange(_:))
    }
    
    func communicateChange(_ entity: LanguageEntity) {
        consultTask.map {
            print("\($0) already running. oops.")
        }
        
        consultTask = Task { [entity] in
            if let modelResponse = await magi.consultModel(about: entity) {
                observations.append(modelResponse)
                print(modelResponse.firstMessage?.content ?? "<no content>")
            } else {
                print("[\(#function)] no change message")
            }
        }
    }
    
    func saveEntity(_ entity: LanguageEntity) {
        do {
            try fileStore.save(entity, to: .custom("\(entity.name)-word-store"))
        } catch {
            print("[\(#function)] \(error)")
        }
    }
}

typealias EntityMap = [String: [String]]

extension EntityMap: RawRepresentable {
    public var rawValue: String {
        do {
            let data = try JSONEncoder().encode(self)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            print(error)
            return ""
        }
    }
    
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let map = try? JSONDecoder().decode(Self.self, from: data)
        else {
            return nil
        }
        self = map
    }
}

struct LanguageEntity: Codable, Equatable, Hashable {
    var name: String
    var definitions: EntityMap = [:]
    
    subscript (_ word: String, _ index: Int = 0) -> String? {
        get {
            if let list = definitions[word],
               list.indices.contains(index) {
                return list[index]
            }
            return nil
        }
        set {
            var list = definitions[word, default: []]
            if list.indices.contains(index) {
                if let newValue {
                    list[index] = newValue
                } else {
                    list.remove(at: index)
                }
            } else {
                if let newValue {
                    list.append(newValue)
                }
            }
            definitions[word] = list
        }
    }
}

class Magi: ObservableObject, Serialized {
    let name: String
    let store: ClientStore
    
    init(
        name: String,
        store: ClientStore
    ) {
        self.name = name
        self.store = store
    }
    
    func consultModel(about entity: LanguageEntity) async -> ChatResult? {
        let rawMap = entity.definitions.rawValue
        guard !rawMap.isEmpty else {
            print("[\(#function)] - no raw map to send")
            return nil
        }
        
        // ask the model about the entity
        store.chat.controlNewConversation()
        await store.chat.snapshotState.updateCurrent { toUpdate in
            let preface = defaultPreface().wrapAsContentOfUserResult(
                model: store.chat.paramState.current.chatModel,
                role: .user
            )
            
            let question = whatDoYouThink().wrapAsContentOfUserResult(
                model: store.chat.paramState.current.chatModel,
                role: .user
            )
            
            let map = rawMap.wrapAsContentOfUserResult(
                model: store.chat.paramState.current.chatModel,
                role: .user
            )
            
            toUpdate.results.append(contentsOf: [
                preface, map, question
            ])
        }
        
        print("[\(#function)] - starting stream")
        let streamResult = await store.chat.startStream()
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

struct EntityDelta {
    static let empty = EntityDelta()
}

struct EntityUnion {
    static let empty = EntityUnion()
}

