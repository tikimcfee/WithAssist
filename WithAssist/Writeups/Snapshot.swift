//
//  Snapshot.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/29/23.
//

import Foundation
import OpenAI

struct Snapshot: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var chatMessages: [OpenAI.Chat] = []
    var errors: [AppError] = []
    var results: [OpenAI.ChatResult] = []
    var name: String = "Some conversation: \(Date.now)"
    
    static let empty: Snapshot = Snapshot()
}

struct SnapshotStore: Codable, Equatable, Hashable {
    var id = UUID()
    var snapshots: [Snapshot] = []
    
    static let empty: SnapshotStore = SnapshotStore()
    
    mutating func update(_ snapshot: Snapshot) {
        if let updateIndex = snapshots.firstIndex(where: { $0.id == snapshot.id }) {
            snapshots[updateIndex] = snapshot
        }
    }
}
