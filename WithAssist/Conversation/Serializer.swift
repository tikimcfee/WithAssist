//
//  Serializer.swift
//  WithAssist
//
//  Created by Ivan Lugo on 4/2/23.
//

import Foundation

actor Serializer: ObservableObject {
    nonisolated func asyncNonIsolated(_ asyncFunction: @escaping () async -> Void) {
        Task {
            await self.performAsync(asyncFunction)
        }
    }
    
    func performAsync(_ asyncFunction: @escaping () async -> Void) {
        Task { await asyncFunction() }
    }
}

protocol Serialized {
    var serializer: Serializer { get }
}

private let globalSerializer = Serializer()
extension Serialized {
    var serializer: Serializer { globalSerializer }
    
    func asyncIsolated(_ asyncFunction: @escaping () async -> Void) {
        serializer.asyncNonIsolated(asyncFunction)
    }
}
