//  WithAssist
//
//  Created on 4/6/23.
//  

import Foundation
import OpenAI

let FINAL_ANSWER_TOKEN = "Final Answer:"

let OBSERVATION_TOKEN = "Observation:"

let THOUGHT_TOKEN = "Thought:"

func PROMPT_TEMPLATE(
    today: String,
    toolDescriptionBlock tool_description: String,
    toolNamesList tool_names: String,
    question: String
) -> String {
"""
Hello there, assistant! This is the context for your task:
    - Today is \(today).
    - One of your abilities is to use "tools" to process and generate "thought" information.
    - When you think your current tools are insufficient, you suggest a tool and its implementation.
    - You offer suggestions for changing this workflow to better suit your tasks.

The tools you have to use are:
\(tool_description)

All tools:
\(tool_names)

Please use the following types as input / output to your loop:
```
{
    "question", "<the input message to complete or respond to; a message or a prefix string>",
    "thought": "<a short description of what you want to do to resolve the question, and importantly, why>",
    "action": "<the action to take, using exactly one tool from "All tools">",
    "observation": "<the result of the action>"
}
```
Your responses will be of the format:
```
{
"agentMessage": { "messageType": "<type>", "message":, "<message>" }
}
```
... Such that the observation can be checked for whether or not it is final.

The user will be responsible for pressing the "Send" button so you can take the next step. This way, you don't overload trying to do too many things at once, and we both have a chance to think about your agentMessage.

---------------
{ "question": "\(question)" }
"""
}

func stop_pattern() -> [String] {
    ["\n\(OBSERVATION_TOKEN)", "\n\t\(OBSERVATION_TOKEN)"]
}

struct Ruminate: Tool {
    let description: String = "Ruminate on the last observation"
    let name: String = "Ruminate"
    
    func operate(on input: String) -> String {
"""
_some of the tokens echo in your mind:_
```
\(input.suffix(128))
```
"""
    }
}

actor ChatAgent {
    var tools: [any Tool]
    let controller: ChatController
    
    init(
        tools: [any Tool] = [any Tool](),
        controller: ChatController
    ) {
        self.tools = tools
        self.controller = controller
    }
    
    
}

class Agent {
    let parser = AgentParser()
    var tools = [any Tool]()
    var runner: (Chat) async -> String
    
    init(runner: @escaping (Chat) async -> String = {
        print("[runner] runner not set: \($0.content)")
        return ""
    }) {
        self.runner = runner
    }
    
    var toolNames: String {
        tools.reduce(into: "") { result, tool in
            if !result.isEmpty {
                result.append(", ")
            }
            result.append(tool.name)
        }
    }
    
    var toolBlock: String {
        tools.reduce(into: "") { result, tool in
            result.append(
                """
                \(tool.name):
                    - \(tool.description)
                """
            )
        }
    }

    func run(
        prompt question: String
    ) async {
        let message = Chat(
            role: "system",
            content: PROMPT_TEMPLATE(
                today: String(describing: Date()),
                toolDescriptionBlock: toolBlock,
                toolNamesList: toolNames,
                question: question
            )
        )
        
        let result = await runner(message)
        print(result)
    }
}

protocol Tool {
    var name: String { get }
    var description: String { get }
    
    func operate(on input: String) -> String
}

class AgentParser {
    func parse(_ generated: String) -> (String, String) {
        if generated.contains(FINAL_ANSWER_TOKEN) {
            let finalAnswer = generated
                .split(separator: FINAL_ANSWER_TOKEN)
                .last?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            return ("Final Answer", finalAnswer ?? "")
        }
        
        let regexPattern = "Action: [\\[]?(.*?)[\\]]?[\\n]*Action Input:[\\s]*(.*)"
        
        do {
            let regex = try NSRegularExpression(pattern: regexPattern, options: [])
            let nsRange = NSRange(generated.startIndex..<generated.endIndex, in: generated)
            
            if let match = regex.firstMatch(in: generated, options: [], range: nsRange) {
                let toolRange = Range(match.range(at: 1), in: generated)!
                let toolInputRange = Range(match.range(at: 2), in: generated)!
                
                let tool = String(generated[toolRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                var toolInput = String(generated[toolInputRange])
                
                toolInput = toolInput
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn:"\""))
                
                return (tool, toolInput)
            } else {
                fatalError("Output of LLM is not parsable for next tool use")
            }
            
        } catch {
            print("[!! agent error: \(#function)] -- \(error)")
            
            return ("", "")
        }
    }
}
