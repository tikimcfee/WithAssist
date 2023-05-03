//
//  ThreeMagiTests.swift
//  WithAssistTests
//
//  Created by Ivan Lugo on 5/2/23.
//

import XCTest
import OpenAI
import Combine
@testable import WithAssist

final class MagiTests: XCTestCase {
    
    var api: OpenAI!
    var bag: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        printSeparator()
        bag = Set()
        
        let token = try XCTUnwrap(OPENAI_API_KEY, "Must have key set in test environment scheme")
        api = OpenAI(apiToken: token)
    }
    
    override func tearDownWithError() throws {
        bag = Set()
        printSeparator()
    }
    
    func testTwoMagi() async throws {
        let magiLove = Magi(name: "MagiOfLove", store: ClientStore(client: api, chat: ChatController(openAI: api)))
        magiLove.store.chat.snapshotState.targetFile = .custom("\(magiLove.name).txt")
        
        let magiReason = Magi(name: "MagiOfReason", store: ClientStore(client: api, chat: ChatController(openAI: api)))
        magiReason.store.chat.snapshotState.targetFile = .custom("\(magiReason.name).txt")
        
        magiLove.store.chat.controlNewConversation()
        magiReason.store.chat.controlNewConversation()

        await withTaskGroup(of: Void.self, body: { group in
            group.addTask(operation: {
                await magiLove.store.chat.addMessage("Hello, \(magiLove.name). I'm Ivan. Great to meet you!")
            })
            
            group.addTask(operation: {
                await magiReason.store.chat.addMessage("Hello, \(magiReason.name). I'm Ivan. Great to meet you!")
            })
            
            while let _ = await group.next() {
                print("Completed a task")
            }
        })
    }
}

class Magi: ObservableObject, Serialized {
    let name: String
    let store: ClientStore
    var bag = Set<AnyCancellable>()
    
    var serializer: Serializer = Serializer()
    lazy var listenQueue = DispatchQueue(label: "\(name)-listening")
    
    init(
        name: String,
        store: ClientStore
    ) {
        self.name = name
        self.store = store
    }
    
    func listen(to otherMagi: Magi) {
        otherMagi.store.chat.snapshotState
            .$publishedSnapshot
            .debounce(for: 2, scheduler: listenQueue)
            .compactMap { $0?.results.last }
            .sink { otherMagiThought in
                self.respond(to: otherMagiThought, from: otherMagi)
            }
            .store(in: &bag)
    }
    
    func respond(to message: ChatResult, from otherMagi: Magi) {
        asyncIsolated { [name] in
            let summary = (message.choices.first?.message?.content ?? "").prefix(32) + "..."
            print("[\(name)] -> [\(otherMagi.name)] : \(summary)")
            await self.store.chat.appendResult(message)
        }
    }
}
