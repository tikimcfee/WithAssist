//
//  Serializer.swift
//  WithAssist
//
//  Created by Ivan Lugo on 4/2/23.
//

import Foundation

actor Serializer: ObservableObject {
    nonisolated func asyncNonIsolated(_ asyncFunction: @escaping () async -> Void) {
        Task.detached(priority: .medium) {
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

extension Serialized {
    func asyncMain(_ asyncFunction: @escaping () async -> Void) {
        serializer.asyncNonIsolated(asyncFunction)
    }
}