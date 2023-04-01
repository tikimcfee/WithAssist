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
    
    var shouldSave: Bool {
        !(isSaved || list.isEmpty)
    }
    
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
    }
    
    mutating func createNewSnapshot() -> (Snapshot, index: Int) {
        let new = Snapshot()
        list.append(new)
        return (new, index: list.endIndex - 1)
    }
    
    mutating func setSaved() {
        isSaved = true
    }
}

struct Snapshot: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var chatMessages: [OpenAI.Chat] = []
    var errors: [AppError] = []
    var results: [OpenAI.ChatResult] = []
    var name: String = "Some conversation: \(Date.now)"
    
    static let empty: Snapshot = {
        let empty = Snapshot()
        print("----- Snapshot.empty set as \(empty.id) -----")
        return empty
    }()
    
    mutating func resetForNewPrompt(_ prompt: String) {
        chatMessages = [
            OpenAI.Chat(role: .system, content: prompt)
        ]
        errors = []
        results = []
    }
}