//
//  WithAssistTests.swift
//  WithAssistTests
//
//  Created by Ivan Lugo on 3/18/23.
//

import XCTest
@testable import WithAssist

final class WithAssistTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testChat() throws {
        let client = AsyncClient()
        
        let expect = expectation(description: "Got a result")
        
        Task { [expect] in
            let snapshot = await client.chat.addMessage("Hello, this is dog")
            XCTAssertFalse(snapshot.chatMessages.isEmpty, "Should receive a response from model")
            expect.fulfill()
        }
        
        wait(for: [expect], timeout: 5.0)
    }

}

func line() {
    print(Array(repeating: "-", count: 16).joined())
}
