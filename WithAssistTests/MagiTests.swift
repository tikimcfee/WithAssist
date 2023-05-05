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
        let magiOne = Magi(
            name: "FirstMagi",
            store: ClientStore(
                client: api,
                chat: ChatController(openAI: api)
            )
        )
        
        let magiTwo = Magi(
            name: "SecondMagi",
            store: ClientStore(
                client: api,
                chat: ChatController(openAI: api)
            )
        )
        
        func setup(magi: Magi) {
            magi.store.chat.snapshotState.targetFile = .custom("Magi:\(magi.name).txt")
        }
        
        setup(magi: magiOne)
        setup(magi: magiTwo)
        
        var testEntity: LanguageEntity = LanguageEntity(name: "Ivan Lugo, of the first test context")
        testEntity["hello"] = "a greeting between entities"
        testEntity["greeting"] = "anything posed in a context meant to engage another entity"
        testEntity["context"] = "the shared moment in relative space in where entities share enough dimensional correlation such that communication is possible"
        print(testEntity.definitions)
        
        let stage = await MagiEntityStage(magi: magiOne, entity: testEntity)
        let result = await magiOne.consultModel(about: testEntity)
        
        print(result?.firstMessage)
        
        XCTAssertNotNil(result, "Model should return a result")
    }
}
