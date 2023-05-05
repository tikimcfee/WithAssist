//
//  Snapshot.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/29/23.
//

import Foundation
import OpenAI

struct AllSnapshots: Codable, Equatable, Hashable, Identifiable {
    var id: UUID = UUID()
    var list: [Snapshot]
    var isSaved: Bool = false
    
    init(list: [Snapshot] = []) {
        self.list = list
    }
    
    mutating func storeChanges(to updatedInstance: Snapshot) {
        let updateIndex = list.firstIndex(where: { $0.id == updatedInstance.id })
        guard let updateIndex else {
            print("[all-snapshots update] No snapshot found with id: \(updatedInstance.id)")
            return
        }
        list[updateIndex] = updatedInstance
        isSaved = false
    }
    
    mutating func createNewSnapshot() -> (Snapshot, index: Int) {
        let new = Snapshot()
        list.append(new)
        isSaved = false
        return (new, index: list.endIndex - 1)
    }
    
    subscript(_ currentIndex: Int) -> Snapshot? {
        guard list.indices.contains(currentIndex)
        else { return nil }
        return list[currentIndex]
    }
}

extension ChatResult: Identifiable { }

struct Snapshot: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var errors: [AppError] = []
    var results: [ChatResult] = []
    var name: String = "\(Date.now)"
    
    static let empty: Snapshot = {
        let empty = Snapshot()
        print("----- Snapshot.empty set as \(empty.id) -----")
        return empty
    }()
    
    mutating func resetForNewPrompt(_ result: ChatResult) {
        results = [result]
        errors = []
    }
    
    internal init(
        id: UUID = UUID(),
        errors: [AppError] = [],
        results: [ChatResult] = [],
        name: String = "\(Date.now)"
    ) {
        self.id = id
        self.errors = errors
        self.results = results
        self.name = name
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.errors = try container.decode([AppError].self, forKey: .errors)
        self.results = try container.decode([ChatResult].self, forKey: .results)
        self.name = try container.decode(String.self, forKey: .name)
    }
}

extension ChatResult {
    var firstMessage: Chat? {
        choices.first?.message
    }
}

extension Snapshot {
    @discardableResult
    mutating func updateResultsFromStream(piece: ChatResult) -> ChatResult {
        if var toUpdate = results[piece.id] {
            for choice in piece.choices {
                toUpdate.upsertChoice(newChoice: choice)
            }
            results[piece.id] = toUpdate
            return toUpdate
        } else {
            results[piece.id] = piece
            return piece
        }
    }
}

extension Array where Element == ChatResult {
    subscript (_ id: ChatResult.ID) -> ChatResult? {
        get { first(where: { $0.id == id }) }
        set {
            let currentIndex = firstIndex(where: { $0.id == id })
            if let newValue {
                if let currentIndex {
                    self[currentIndex] = newValue
                } else {
                    self.append(newValue)
                }
            } else {
                if let currentIndex {
                    self.remove(at: currentIndex)
                }
            }
        }
    }
}

extension ChatResult {
    mutating func upsertChoice(
        newChoice: Choice
    ) {
        if let delta = newChoice.delta {
            choices.upsertDelta(newChoice, delta)
        }
        else if let message = newChoice.message {
            choices.upsertMessage(newChoice, message)
        }
    }
}

extension Array where Element == ChatResult.Choice {
    mutating func upsertDelta(
        _ newChoice: Element,
        _ delta: ChatResult.Choice.Delta
    ) {
        if indices.contains(newChoice.index) {
            self[newChoice.index].upsertDelta(delta)
        } else {
            self.append(newChoice)
        }
    }
    
    mutating func upsertMessage(
        _ newChoice: Element,
        _ message: Chat
    ) {
        if indices.contains(newChoice.index) {
            self[newChoice.index].upsertMessage(message)
        } else {
            self.append(newChoice)
        }
    }
}

extension ChatResult.Choice {
    mutating func upsertDelta(
        _ delta: Delta
    ) {
        if var toUpdate = message {
            toUpdate.content.append(delta.content ?? "")
            message = toUpdate
        } else {
            message = Chat(
                role: delta.role ?? .assistant,
                content: delta.content ?? ""
            )
        }
    }
    
    mutating func upsertMessage(
        _ newMessage: Chat
    ) {
        if message != nil {
            print("--- skipping message set; already exists")
            return
        } else {
            message = newMessage
        }
    }
}
