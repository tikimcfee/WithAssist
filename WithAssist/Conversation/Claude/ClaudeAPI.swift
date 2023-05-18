//  WithAssist
//
//  Created on 5/17/23.
//

private let HUMAN_STOP_SEQUENCE = ["\n\nHuman:"]
private let HUMAN_PROMPT = "\n\nHuman: "
private let ASSISTANT_PROMPT = "\n\nAssistant: "

import Foundation

class ClaudeClient {
    let apiKey: String
    let apiURL = "https://api.anthropic.com"
    let defaultTimeout: TimeInterval = 600
    
    var configuration: URLSessionConfiguration {
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.httpAdditionalHeaders = [
            "X-API-Key": apiKey,
            "Accept": "application/json",
            "Client": "Anthropic SDK v1.0"
        ]
        sessionConfiguration.timeoutIntervalForRequest = 600
        sessionConfiguration.timeoutIntervalForResource = 900
        return sessionConfiguration
    }
    
    lazy var session: URLSession = {
        URLSession(configuration: configuration)
    }()
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func asyncCompletionStream(
        request: Request
    ) -> AsyncThrowingStream<Response, Error> {
        AsyncThrowingStream { continuation in
            guard let data = request.asData() else {
                continuation.finish(throwing: ClaudeError.invalidRequestData)
                return
            }
            
            let urlRequest = self.makeURLRequest(
                method: "POST",
                path: "/v1/complete",
                params: data
            )
            
            let session = StreamingSession<Response>(
                urlRequest: urlRequest,
                configure: { self.configuration }
            )
            
            session.onReceiveContent = { session, value in
                continuation.yield(value)
            }
            
            session.onComplete = { session, error in
                if let error {
                    continuation.finish(throwing: error)
                } else {
                    continuation.finish()
                }
            }
            
            session.onProcessingError = { session, error in
                continuation.finish(throwing: error)
            }
            session.perform()
        }
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
