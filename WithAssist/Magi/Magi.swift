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
        consultTask = Task {
            if let modelResponse = await magi.consultModel() {
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
    
    subscript (_ word: String) -> [String] {
        get {
            entity.definitions[word, default: []]
        }
        set {
            entity.definitions[word] = newValue
        }
    }
}

struct LanguageEntity: Codable, Equatable, Hashable {
    var name: String
    var definitions: [String: [String]] = [:]
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
    
    func consultModel() async -> ChatResult? {
        let streamResult = await store.chat.startStream()
        
        // ask the model about the entity
        
        return streamResult
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

