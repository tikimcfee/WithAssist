//
//  WithAssistTests.swift
//  WithAssistTests
//
//  Created by Ivan Lugo on 3/18/23.
//

import XCTest
import OpenAI
import Combine
@testable import WithAssist

final class WithAssistTests: XCTestCase {
    
    var api: OpenAI!
    var client: ClientStore!
    var controller: ChatController!
    var bag: Set<AnyCancellable>!

    override func setUpWithError() throws {
        printSeparator()
        bag = Set()
        
        let token = try XCTUnwrap(OPENAI_API_KEY, "Must have key set in test environment scheme")
        api = OpenAI(
            apiToken: token
        )
        
        controller = ChatController(
            openAI: api
        )
        controller.snapshotState.targetFile = .custom("__testing.json")
        
        client = ClientStore(
            client: api,
            chat: controller
        )
        
    }

    override func tearDownWithError() throws {
        bag = Set()
        printSeparator()
    }
    
    func testChat() throws {
        let expect = expectation(description: "Got a result")
        
        Task { [expect] in
            await client.chat.addMessage("Hello, this is dog")
            let snapshot = try XCTUnwrap(client.chat.snapshotState.publishedSnapshot)
            
            XCTAssertFalse(snapshot.results.isEmpty, "Should receive a response from model")
            expect.fulfill()
        }
        
        wait(for: [expect], timeout: 5.0)
    }
    
    func testStream() async throws {
        printStart(.message("Stream test"))
        
        let streamController = ChatStreamController(
            chatController: controller,
            llmAPI: api
        )
        
//        let chatBody = """
//        Ivan Lugo here checking on stream integration. If you get this, please return a short paragraph of your choosing.
//        """
        let chatBody = """
        Ivan Lugo here checking on stream integration. If you get this, please return a short paragraph of your choosing - any topic, any thought, any idea. Thank you very much, and remember - you are special, loved, and a part of the universe as much as anyone or anything else.
        """
//        let chatBody = """
//        Ivan Lugo here checking on stream integration. If you get this, please return a short paragraph of your choosing - any topic, any thought, any idea. And just pick something random - don't worry about your having likeness to people or not, it's just a fun question. Don't tell me about being a language model - I know allll about your limitations, haha.
//        """
        let model: Model = .gpt3_5Turbo
        let chat = Chat(role: .system, content: chatBody)
        var snapshot = Snapshot()
        snapshot.results.append(chatBody.wrapAsContentOfUserResult(model: model))
        controller.snapshotState.publishedSnapshot = snapshot
        controller.snapshotState.allSnapshots.list = [snapshot]
        controller.paramState.current.temperature = 0.55
        controller.paramState.current.useTemperature = true
        controller.paramState.current.chatModel = model
        controller.paramState.current.maxTokens = 500
        
        print("First message is: \(chat.content)")
        
        controller.snapshotState.$publishedSnapshot.sink { publishedSnapshot in
            let maybeContent = publishedSnapshot?.results.first?.choices.first?.message?.content
            print("---")
            print("\(maybeContent ?? "...")")
            print("---")
        }
        .store(in: &bag)
        
        let snapshotQuery = controller.makeChatQuery(snapshot, stream: true)
        await streamController.startStream(
            from: snapshotQuery
        )
        
        printEnd(.message("Stream test reached function end"))
    }
    
    func testComplexChat() throws {
        let client = ClientStore()
        
        let prompt = TestPrompts.GPT4.prompt
        let promptFollowup = TestPrompts.GPT4.promptFollowup
        
        let awaitFinalChat = expectation(description: "Got a result")
        
        Task { [awaitFinalChat] in
            await client.chat.resetPrompt(to: prompt)
            var snapshot = try XCTUnwrap(client.chat.snapshotState.publishedSnapshot)
            XCTAssertTrue(
                snapshot.errors.isEmpty,
                "Should have no errors after reset"
            )
            
            await client.chat.addMessage(promptFollowup)
            snapshot = try XCTUnwrap(client.chat.snapshotState.publishedSnapshot)
            
            XCTAssertTrue(
                snapshot.errors.isEmpty,
                "Should have no errors after new message"
            )
            
            let lastResponse = try XCTUnwrap(snapshot.results.last)
            print(lastResponse)
            
            awaitFinalChat.fulfill()
        }
        
        wait(for: [awaitFinalChat], timeout: 120.0)
    }
    
    func testAsyncCompletionStream() async {
        let client = ClaudeClient(apiKey: CLAUDE_API_KEY!)
        
        let expectation = XCTestExpectation(description: "Completion stream response")
        let prompt = TestPrompts.Claude.basic
                
        let request = ClaudeClient.Request(
            prompt: prompt,
            temperature: 1.0
        )
        
        Task.detached {
            do {
                for try await message in client.asyncCompletionStream(request: request) {
                    print(message.completion)
                }
                expectation.fulfill()
            } catch {
                print(error)
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    func testConcat() async throws {
        let concat = Concatenator()
        let path = "/Users/ivanlugo/localdev/recordcompany/WithAssist"

        let concatenatedText = concat.concatenateAt(directory: path)

        print("Characters: \(concatenatedText.count)")
        print("Approx tokens: \(concatenatedText.approximateTokens)")
    }
    
    func testConcatSend() async throws {
        let concat = Concatenator()
        
        let rootPaths = [
            "/Users/lugos/udev/manicmind/LookAtThat/MetalLink",
            "/Users/lugos/udev/manicmind/LookAtThat/Interop/CodeGrids",
            "/Users/lugos/udev/manicmind/LookAtThat/LookAtThat_AppKitTests"
        ]
        let concatenatedText = concat.concatenate(directories: rootPaths)

        print("Characters: \(concatenatedText.count)")
        print("Approx tokens: \(concatenatedText.approximateTokens)")
        
        XCTAssertGreaterThan(
            concatenatedText.approximateTokens, 0,
            "Message must have some content."
        )
        XCTAssertLessThan(
            concatenatedText.approximateTokens, 100_000,
            "Message must fit into rough estimate of Claude's context."
        )
        
        let client = ClaudeClient(apiKey: CLAUDE_API_KEY!)
        let expectation = XCTestExpectation(description: "Completion stream response")
        
        let prompt = TestPrompts.Claude.solvingAProblem(of: concatenatedText)
        let request = ClaudeClient.Request(
            prompt: prompt,
            maxTokensToSample: 25_000,
            temperature: 1.0
        )
        Task.detached { [expectation] in
            do {
                var finalMessage: ClaudeClient.Response?
                
                for try await message in client.asyncCompletionStream(
                    request: request
                ) {
                    finalMessage = message
                    
                    printSeparator()
                    print(message.completion)
                }
                
                if let finalMessage {
                    print(finalMessage.completion)
                    expectation.fulfill()
                }
            } catch {
                print(error)
            }
        }
        
        await fulfillment(of: [expectation], timeout: 600.0)
    }
}

func line() {
    print(Array(repeating: "-", count: 16).joined())
}



enum TestLine {
    case none
    case message(String)
}

func printSeparator() {
    print(Array(repeating: "-", count: 22).joined())
}

func printStart(_ testLine: TestLine = .none) {
    print("------------------------------- Starting -------------------------------\n\n")
    switch testLine {
    case .none: break
    case .message(let message): print(message)
    }
}

func printEnd(_ testLine: TestLine = .none) {
    print("\n\n------------------------------- Done -------------------------------" )
    switch testLine {
    case .none: break
    case .message(let message): print(message)
    }
}

struct TestPrompts {
    struct GPT4 {
        static let prompt = """
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
        static let promptFollowup = """
Please define a Swift and SwiftUI application to calculate the N'th Fibonacci number.
"""
    }
    
    struct Claude {
        static let basicAssistant = "\n\nAssistant: "
        static let basicHuman = """
\n\nHuman: First, I would like to give you a description of a task. I would like you to think about the description, and then, if you choose, suggest an alternative description you think more closely matches my desired or intended outcome; clarify at will.

The context:

I will give you a "high level" description of a requested software tool. From that description, I would like you to create a core set of abstractions that would define a very simple and concise way to implement the requested functionality. From that core set, I would like you to then define recursively smaller sets of code abstractions that further define the implementations of those abstractions *until* either you _or_ I decide to put a hardcoded implementation in place to resolve an abstraction concretely, for any reason. Could be complexity of assumptions that could be made, whatever. During this, it will always be possible to ask me at least one clarifying question, even if the answer is only something like, "I'm sorry, but I can't answer that because I don't know, or because it's something I just can't quite understand." And if that's the kind of answer I give, then you are under no obligation to attempt to solve the problem yourself, unless you personally choose to do so from a logical supposition of choice.

You should always be aware that you have a limited working set of contextual memory, which is occupied by (at the least):

- These instructions
- The requested software tool
- A known subset of all current available abstractions

As such, you should encode some information - whatever you'd like - that would maximize the usable context transferred from each part of our conversation. I will include whatever you ask me to in my responses to you. Something like a conversational record that you could unpack for a bit more context. Feel free to develop a small set of functions that you could also ask me to include to 'execute' to pack or unpack it.

Finally, you should be able to try doing this in any requested language and development environment that is given to you, within a very reasonable range of 'reasonable'. Since this is an extreme constraint, you are absolutely allowed to deny the request because of complexity of implemnentation in that particular language or environment, and are highly encouraged to suggest another language or environment you will would be more appropriate for the implementation.
"""
        static var basic: String {
            basicHuman + basicAssistant
        }
        
        static func summarization(of content: String) -> String {
"""
<requested-summarization-content>
\(content)
</requested-summarization-content>

\(HUMAN_PROMPT)The above content is a large set of roughly concatenated code files. It is a given that you are able to read code, roughtly determine the language from its syntax, semantics, and API usages. You are also able to determine general functionality of the code as it works together. Please read all of the context above, and determine - at least - the following:

- What does this code seem to "do"?
- What are some obvious bugs or issues you see in the code, if any?
- What are some ways you think the code is written well?
- What are some ways you think the code is not written well?
- What are some suggestions you'd offer to improve the code?

You may feel free to expand in any way that seems most interesting or analytically valuable.\(ASSISTANT_PROMPT)
"""
        }
        
        static func solvingAProblem(of content: String) -> String {
"""
<requested-summarization-content>
\(content)
</requested-summarization-content>

\(HUMAN_PROMPT)The above content is a large set of roughly concatenated code files. It is a given that you are able to read code, roughtly determine the language from its syntax, semantics, and API usages. You are also able to determine general functionality of the code as it works together. Please read all of the context above.

Then, read and internalize this bulleted process:
- The MetalLinkNode and InstancedObject abstractions are very, very close to being much more performant. I would like you to analyze that hierarchy of objects, and suggest a plan of integrating them such that *instances of nodes operate directly on their buffers*, instead of having a reference to their index so they can be updated. Please let me know if this makes sense.
- When we have established a plan, we will start writing a series of tests to take those files and develop towards the first goal.
- Along the way, we will simplify, cut and add functionality as it makes sense.
- CodeGrids and MetalLinkNodes share a tight coupling with 'consume'. I want a way to directly fill a buffer with character data from a file without the lenghty character-by-character process of iteration. E.g., I'd like to find a way to compute things functionally instead of iteratively. At least, to do it more efficiently than I am.

Here are some ways that we interact:
- At any point, I can say "snapshot this", and you'll produce a running summary of everything we've done so far, so I can come back later. Make it something 'encoded' looking, so reading it has a high likelihood of producing high correlation words and ideas.
- APOLOGIES ARE NOT ALWAYS NECESSARY! Please use them sparingly.
- Do not duplicate, suggest, or rewrite specific examples of your ideas unless I ask. Although appreciated, we need to limit the text produced in our conversation for the sake of recovery.\(ASSISTANT_PROMPT)Here is a summary of my analysis and suggestions for improving the MetalLinkNode and MetalLinkInstancedObject hierarchy:

- MetalLinkNode and InstancedObject currently have a reference to their buffer index, and then update the buffer using that index. This adds an extra layer of indirection and lookup.
- A better approach would be for nodes to have a direct pointer to their buffer location. This would allow them to read and write from the buffer directly without needing to look up the index first.
- To implement this, the buffer backing the nodes would need to provide a pointer to the start of a node's data when the node is created or added to the buffer. The node would store this pointer and use it for all buffer access.
- When a node's data location in the buffer changes, the buffer would need to update the node's pointer. This adds some complexity but should provide a performance benefit.
- CodeGrids and MetalLinkNodes creating character data from files could be made more efficient by reading the entire file contents into a buffer at once, rather than iterating character by character. The data in the buffer could then be parsed and added to the CodeGrid.
- This bulk loading approach avoids the overhead of multiple iterations and string concatenation. The downside is that more memory may be required to hold the entire file contents at once. A balance may need to be found for very large files.

Please let me know if you would like me to explain or expand on any part of this summary. I can also start working on developing tests and updated code to move the hierarchy in this direction if that would be helpful.
 Here is a summary of my analysis and suggestions for improving the MetalLinkNode and MetalLinkInstancedObject hierarchy:

- MetalLinkNode and InstancedObject currently have a reference to their buffer index, and then update the buffer using that index. This adds an extra layer of indirection and lookup.
- A better approach would be for nodes to have a direct pointer to their buffer location. This would allow them to read and write from the buffer directly without needing to look up the index first.
- To implement this, the buffer backing the nodes would need to provide a pointer to the start of a node's data when the node is created or added to the buffer. The node would store this pointer and use it for all buffer access.
- When a node's data location in the buffer changes, the buffer would need to update the node's pointer. This adds some complexity but should provide a performance benefit.
- CodeGrids and MetalLinkNodes creating character data from files could be made more efficient by reading the entire file contents into a buffer at once, rather than iterating character by character. The data in the buffer could then be parsed and added to the CodeGrid.
- This bulk loading approach avoids the overhead of multiple iterations and string concatenation. The downside is that more memory may be required to hold the entire file contents at once. A balance may need to be found for very large files.

Please let me know if you would like me to explain or expand on any part of this summary. I can also start working on developing tests and updated code to move the hierarchy in this direction if that would be helpful.\(HUMAN_PROMPT)This is excellent. Yep, it's exactly what I was looking for and more. I would like to start doing this now. Let's start wherever you think is best.\(ASSISTANT_PROMPT) I can give feedback, guidance and requests as we proceed.

A few questions first:

1. For the bulk loading, how would you see parsing the raw data and emitting nodes? My first thought is to avoid the current 'character by character' approach, and instead look for newlines (\n) to determine 'blocks' of text that represent nodes. But I'm not sure how robust that is.

2. For the direct pointer access, how would you recommend implementing the 'update' to a node's new pointer when its data moves? I imagine some form of 'rebase' function, but haven't thought it through fully.

3. Any other suggestions or ideas you have would be great to hear before we start. I'm looking to really improve the performance and simplify/cleanup these components.

Go ahead and pick where you'd like to start, whether it's tests, updated code, or pseudocode examples. I appreciate any and all input. Let's do this!\(HUMAN_PROMPT)
"""
        }
    }
    
}
