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
        let magi = Magi(name: "FirstMagi", store: ClientStore(client: api, chat: ChatController(openAI: api)))
        magi.store.chat.snapshotState.targetFile = .custom("\(magi.name).txt")
        
        magi.store.chat.controlNewConversation()
    }
}
