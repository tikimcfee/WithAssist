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
    let store: ClientStore
    var bag = Set<AnyCancellable>()
    
    var serializer: Serializer = Serializer()
    lazy var listenQueue = DispatchQueue(label: "\(name)-weewwdz")
    
    @Published var lastThought: ChatResult?
    private var lastThoughtSummary: String {
        (lastThought?.choices.first?.message?.content ?? "<nothing chosen>").prefix(32) + "..."
    }
    
    init(
        name: String,
        store: ClientStore
    ) {
        self.name = name
        self.store = store
        
        store.chat.snapshotState
            .$publishedSnapshot
            .compactMap { $0?.results.last }
            .debounce(for: 2, scheduler: listenQueue)
            .removeDuplicates { left, right in
                left.id == right.id
                && left.firstMessage?.content.count == right.firstMessage?.content.count
            }
            .sink { lastResult in
                self.lastThought = lastResult
                print("\t\t{ Magi: \(name) } - Set new thought: \(self.lastThoughtSummary)")
            }.store(in: &bag)
    }
    
    func listen(to otherMagi: Magi) {
        otherMagi.$lastThought
            .compactMap { $0 }
            .sink { otherMagiThought in
                self.respond(to: otherMagiThought, from: otherMagi)
            }
            .store(in: &bag)
    }
    
    func respond(to result: ChatResult, from otherMagi: Magi) {
        asyncIsolated { [name] in
            var result = result
            result.choices[0].message = result.firstMessage?.transform(role: .user)
            
            print("\t[\(name)] -> [\(otherMagi.name)] :::: (\(self.lastThoughtSummary))")
            await self.store.chat.appendResult(result)
        }
    }
}
