//  WithAssist
//
//  Created on 5/17/23.
//

let HUMAN_STOP_SEQUENCE = ["\n\nHuman:"]
let HUMAN_PROMPT = "\n\nHuman: "
let ASSISTANT_PROMPT = "\n\nAssistant: "

let JSON_ENCODER = JSONEncoder()
let JSON_DECODER = JSONDecoder()

import Foundation

class ClaudeClient {
    let apiKey: String
    let apiURL = "https://api.anthropic.com"
    let defaultTimeout: TimeInterval = 600
    
    var session: URLSession
    
    init(apiKey: String) {
        self.apiKey = apiKey
        self.session = URLSession(configuration: {
            let sessionConfiguration = URLSessionConfiguration.default
            sessionConfiguration.httpAdditionalHeaders = [
                "X-API-Key": apiKey,
                "Accept": "application/json",
                "Client": "Anthropic SDK v1.0"
            ]
            sessionConfiguration.timeoutIntervalForRequest = 600
            sessionConfiguration.timeoutIntervalForResource = 900
            return sessionConfiguration
        }())
    }
    
    func asyncCompletion(
        request: Request
    ) -> AsyncThrowingStream<Response, Error> {
        AsyncThrowingStream { continuation in
            guard let data = request.asData() else {
                continuation.finish(throwing: ClaudeError.invalidRequestData)
                return
            }
            
            let urlRequest = makeURLRequest(method: "POST", path: "/v1/complete", params: data)
            
            let task = session.dataTask(with: urlRequest) { data, response, error in
                self.streamTaskReceiver(
                    data: data,
                    response: response,
                    error: error,
                    continuation: continuation
                )
            }
            task.resume()
        }
    }
    
    func completion(
        params: [String: Any],
        receiver: @escaping ([String: Any]?) -> Void
    ) {
        let urlRequest = makeURLRequestParams(method: "POST", path: "/v1/complete", params: params)
        let task = session.dataTask(with: urlRequest) { data, response, error in
            if let error {
                print(error)
            }
            
            guard let data = data
            else {
                receiver(nil)
                return
            }
            
            guard let response = response as? HTTPURLResponse,
                  response.statusCode == 200
            else {
                print("POST /v1/complete failed with response: ", response ?? "No response")
                receiver(nil)
                return
            }
            
            // Handle streaming API request
            let dataLines = data.split(separator: Data([13, 10]))
            
            for line in dataLines {
                let str = String(decoding: line, as: UTF8.self)
                print("--Decoded line:\n", "```", str, "```", "\n--")
                
                guard !str.contains("data: [DONE]") else {
                    print("-- found [DONE]")
                    continue
                }
                
                let offset = str.index(str.startIndex, offsetBy: 6)
                guard str.indices.contains(offset) else {
                    print("Invalid stream offset:", offset)
                    continue
                }
                
                let json = str[str.index(str.startIndex, offsetBy: 6)...]
                
                if let parsedJSON = try? self.parseJSON(json: json) as? [String: Any] {
                    print("-- parsed response")
                    
                    let hasStop = parsedJSON.maybeStop != nil
                    if let maybeCompletion = parsedJSON.maybeCompletion {
                        print("Message: \(maybeCompletion)")
                        
                        if hasStop {
                            receiver(parsedJSON)
                        }
                    }
                } else {
                    print("-- no response parsed")
                    receiver(nil)
                }
            }
        }
        task.resume()
    }
    
    private func streamTaskReceiver(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        continuation: AsyncThrowingStream<Response, Error>.Continuation
    ) {
        guard let data else {
            continuation.finish(throwing: ClaudeError.noResponseData)
            return
        }
        
        if let error {
            continuation.finish(throwing: ClaudeError.responseError(error))
            return
        }
        
        guard let response = response as? HTTPURLResponse else {
            continuation.finish(throwing: ClaudeError.notAnHTTPResponse)
            return
        }
        
        guard response.statusCode == 200 else {
            continuation.finish(throwing: ClaudeError.invalidResponseCode(response.statusCode, response))
            return
        }
        
        // Handle streaming API request
        
        // Data([13, 10]) == "\r\n", data line separator
        let dataLines = data.split(separator: Data([13, 10]))
        
        for line in dataLines {
            let lineString = String(decoding: line, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
//            print("--Decoded line:\n", "```", lineString, "```", "\n--")
            
            guard !lineString.starts(with: "data: [DONE]") else {
//                print("-- found [DONE]")
                continue
            }
            
            let offset = lineString.index(lineString.startIndex, offsetBy: 6)
            guard lineString.indices.contains(offset) else {
//                print("Invalid stream offset:", offset)
                continue
            }
            
            let json = lineString[lineString.index(lineString.startIndex, offsetBy: 6)...]
            
            do {
                if let claudeResponse = try ClaudeClient.Response.fromJsonString(json) {
//                    print("-- parsed response")
                    continuation.yield(claudeResponse)
                    
                    if claudeResponse.stop != nil {
                        continuation.finish()
                    }
                } else {
//                    print("-- failed to parse a response")
                }
            } catch {
                continuation.finish(throwing: ClaudeError.responseError(error))
                return
            }
        }
        
        continuation.finish()
    }
    
    private func makeURLRequest(
        method: String,
        path: String,
        params: Data,
        headers: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) -> URLRequest {
        let url = URL(string: apiURL + path)!
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout ?? defaultTimeout
        if let headers = headers {
            request.allHTTPHeaderFields = headers
        }
        
        if !params.isEmpty {
            request.httpBody = params
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        return request
    }
    
    private func makeURLRequestParams(
        method: String,
        path: String,
        params: [String: Any],
        headers: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) -> URLRequest {
        let url = URL(string: apiURL + path)!
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout ?? defaultTimeout
        if let headers = headers {
            request.allHTTPHeaderFields = headers
        }
        
        if !params.isEmpty {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: params, options: [])
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                print(error)
            }
        }
        
        return request
    }
    
    private func parseJSON(json: Substring) throws -> Any? {
        do {
            if let data = json.data(using: .utf8) {
                return try JSONSerialization.jsonObject(with: data, options: [])
            }
        } catch {
            throw error
        }
        return nil
    }
    
    func getCompletion(_ response: [String: Any]) -> String? {
        response["completion"] as? String
    }
}

extension ClaudeClient {
    enum ClaudeError: Error {
        case invalidRequestData
        case noResponseData
        case responseError(Error)
        case notAnHTTPResponse
        case invalidResponseCode(Int, HTTPURLResponse)
    }
    
    struct Response: Codable {
        let completion: String
        let model: String
        let stop: String?
        let exception: String?
    }
    
    struct Request: Codable {
        let prompt: String
        
        let model: String
        let stream: Bool
        let maxTokensToSample: Int
        let stopSequences: [String]
        let temperature: Float
        
        init(
            prompt: String,
            model: String = "claude-v1.3-100k",
            stream: Bool = true,
            maxTokensToSample: Int = 500,
            stopSequences: [String] = HUMAN_STOP_SEQUENCE,
            temperature: Float = 0.7
        ) {
            self.prompt = prompt
            self.model = model
            self.stream = stream
            self.maxTokensToSample = maxTokensToSample
            self.stopSequences = stopSequences
            self.temperature = temperature
        }

        
        enum CodingKeys: String, CodingKey {
            case prompt
            case stream
            case model
            case maxTokensToSample = "max_tokens_to_sample"
            case stopSequences = "stop_sequences"
            case temperature
        }
    }
}

// ------- Extensions

extension Encodable {
    func asData() -> Data? {
        try? JSON_ENCODER.encode(self)
    }
}

extension Decodable {
    static func fromJsonString(_ string: Substring) throws -> Self? {
        if let data = string.data(using: .utf8) {
            return try JSON_DECODER.decode(Self.self, from: data)
        }
        return nil
    }
}

extension Dictionary where Key == String, Value == Any {
    var maybeCompletion: String? {
        self["completion"] as? String
    }
    
    var maybeStop: String? {
        self["stop"] as? String
    }
}
