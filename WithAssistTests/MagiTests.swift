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
            controller: ChatController(openAI: api)
        )
        
        let magiTwo = Magi(
            name: "SecondMagi",
            controller: ChatController(openAI: api)
        )
        
        var testEntity: LanguageEntity = LanguageEntity(name: "Ivan Lugo, of the first test context")
        testEntity["hello"].append("a greeting between entities")
        testEntity["greeting"].append("anything posed in a context meant to engage another entity")
        testEntity["context"].append("the shared moment in relative space in where entities share enough dimensional correlation such that communication is possible")
        print(testEntity.definitions)
        
//        let stage = MagiEntityStage(magi: magiOne, entity: testEntity)
        magiOne.controller.paramState.current.chatModel = .gpt3_5Turbo
        magiOne.controller.paramState.current.maxTokens = 2056

        magiOne.controller.paramState.current.useTemperature = true
        magiOne.controller.paramState.current.temperature = 0.0
        
        magiOne.controller.paramState.current.useUser = true
        magiOne.controller.paramState.current.user = magiOne.name
        
        var result = await magiOne.consultModel(about: testEntity)
        print(try XCTUnwrap(result?.firstMessage, "Must have a result from magi"))
        
        /* -- First Result --
         --------------------------------------------------------------------
         default params
         --------------------------------------------------------------------
         
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
        
        /* -- Second Result --
         --------------------------------------------------------------------
             magiOne.controller.paramState.current.maxTokens = 2056

             magiOne.controller.paramState.current.useTemperature = true
             magiOne.controller.paramState.current.temperature = 0.0
             
             magiOne.controller.paramState.current.useUser = true
             magiOne.controller.paramState.current.user = magiOne.name
         --------------------------------------------------------------------
         
         Based on the given dictionary, some notable analytic features of the words are:

         1. The words "hello" and "greeting" are related to each other as "hello" is defined as a type of greeting.
         2. The definition of "greeting" includes the phrase "posed in a context meant to engage another entity," which suggests that greetings are intended to initiate communication or interaction between entities.
         3. The definition of "context" emphasizes the importance of shared space and dimensional correlation for communication to occur.

         From these features, we can conclude that the dictionary is focused on defining words related to communication and interaction between entities. However, we cannot make any conclusions about the specific entity for which this dictionary was created or their language proficiency level based solely on these definitions. Additionally, there may be other definitions for these words that are not included in this particular dictionary.
         */
    }
}
