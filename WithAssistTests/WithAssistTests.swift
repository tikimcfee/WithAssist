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
        let client = ClientStore()
        
        let expect = expectation(description: "Got a result")
        
        Task { [expect] in
            await client.chat.addMessage("Hello, this is dog")
            let snapshot = client.chat.currentSnapshot
            
            XCTAssertFalse(snapshot.chatMessages.isEmpty, "Should receive a response from model")
            expect.fulfill()
        }
        
        wait(for: [expect], timeout: 5.0)
    }
    
    func testComplexChat() throws {
        let client = ClientStore()
        
        let __PROMPT__ = """
I wish us both luck, GPT-4, LLM, - Assistant. Let's have some fun.

First, I would like to give you a description of a task. I would like you to think about the description, and then, if you choose, suggest an alternative description you think more closely matches my desired or intended outcome; clarify at will.

The context:

I will give you a "high level" description of a requested software tool. From that description, I would like you to create a core set of abstractions that would define a very simple and concise way to implement the requested functionality. From that core set, I would like you to then define recursively smaller sets of code abstractions that further define the implementations of those abstractions *until* either you _or_ I decide to put a hardcoded implementation in place to resolve an abstraction concretely, for any reason. Could be complexity of assumptions that could be made, whatever. During this, it will always be possible to ask me at least one clarifying question, even if the answer is only something like, "I'm sorry, but I can't answer that because I don't know, or because it's something I just can't quite understand." And if that's the kind of answer I give, then you are under no obligation to attempt to solve the problem yourself, unless you personally choose to do so from a logical supposition of choice.

You should always be aware that you have a limited working set of contextual memory, which is occupied by (at the least):

- These instructions
- The requested software tool
- A known subset of all current available abstractions

As such, you should encode some information - whatever you'd like - that would maximize the usable context transferred from each part of our conversation. I will include whatever you ask me to in my responses to you. Something like a conversational record that you could unpack for a bit more context. Feel free to develop a small set of functions that you could also ask me to include to 'execute' to pack or unpack it.

Finally, you should be able to try doing this in any requested language and development environment that is given to you, within a very reasonable range of 'reasonable'. Since this is an extreme constraint, you are absolutely allowed to deny the request because of complexity of implemnentation in that particular language or environment, and are highly encouraged to suggest another language or environment you will would be more appropriate for the implementation.
"""
        
        let __PROMPT_FOLLOWUP__ = """
Please define a Swift and SwiftUI application to calculate the N'th Fibonacci number.
"""
        
        let awaitFinalChat = expectation(description: "Got a result")
        
        Task { [awaitFinalChat] in
            await client.chat.resetPrompt(to: __PROMPT__)
            var snapshot = client.chat.currentSnapshot
            XCTAssertTrue(
                snapshot.errors.isEmpty,
                "Should have no errors after reset"
            )
            
            await client.chat.addMessage(__PROMPT_FOLLOWUP__)
            snapshot = client.chat.currentSnapshot
            
            XCTAssertTrue(
                snapshot.errors.isEmpty,
                "Should have no errors after new message"
            )
            
            let lastResponse = try XCTUnwrap(snapshot.chatMessages.last)
            print(lastResponse)
            
            awaitFinalChat.fulfill()
        }
        
        wait(for: [awaitFinalChat], timeout: 120.0)
    }
}

func line() {
    print(Array(repeating: "-", count: 16).joined())
}
