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
        /* -- First Result --
         Based on the provided dictionary, I can make a few observations:

         1. The definitions are focused on communication and interaction between entities.
         2. The concept of "entities" is central to these definitions, suggesting that the entity providing the dictionary values interpersonal connections.
         3. The definition of "context" introduces the idea of dimensional correlation, implying that the entity might have a scientific or philosophical perspective on communication.

         However, there are limitations to the conclusions I can draw from this small sample:

         1. It is not possible to determine the overall scope or theme of the entire personal dictionary based on just three entries.
         2. We cannot deduce specific preferences or beliefs held by the entity beyond their interest in communication and interactions.
         3. We do not know how these words relate to other words in their personal dictionary or if there are any patterns in word usage.

         To gain a more comprehensive understanding of this individual's language and thought processes, we would need access to a larger portion of their personal dictionary with more diverse entries.
         */
    }
}
