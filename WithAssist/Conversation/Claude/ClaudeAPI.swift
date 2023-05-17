//  WithAssist
//
//  Created on 5/17/23.
//

import Foundation

enum ApiException: Error {
    case failedRequest(String, Any)
}

class ClaudeClient {
    let apiKey: String
    let apiURL = "https://api.anthropic.com"
    let defaultTimeout: TimeInterval = 600
    
    var session: URLSession
    
    init(apiKey: String, proxyURL: String? = nil) {
        self.apiKey = apiKey
        
        self.session = URLSession(configuration: {
            let sessionConfiguration = URLSessionConfiguration.default
            sessionConfiguration.httpAdditionalHeaders = [
                "X-API-Key": apiKey,
                "Accept": "application/json",
                "Client": "Anthropic SDK v1.0"
            ]
            if let proxyURL = proxyURL {
                sessionConfiguration.connectionProxyDictionary = [
                    "https": proxyURL
                ]
            }
            sessionConfiguration.timeoutIntervalForRequest = 600
            sessionConfiguration.timeoutIntervalForResource = 900
            return sessionConfiguration
        }())
    }
    
    func request(
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
                // Log JSON serialization error
                print(error)
            }
        }
        
        return request
    }
    
    func completion(
        params: [String: Any],
        receiver: @escaping ([String: Any]) -> Void
    ) {
        let urlRequest = request(method: "POST", path: "/v1/complete", params: params)
        
        let task = session.dataTask(with: urlRequest) { data, response, error in
            guard let data = data
            else {
                print(String(describing: error))
                return
            }
            
            guard let response = response as? HTTPURLResponse,
                  response.statusCode == 200
            else {
                return
            }
            let maybeJSON = try? JSONSerialization.jsonObject(with: data, options: [])
            
            if let parsedObject = maybeJSON as? [String: Any] {
                receiver(parsedObject)
            } else {
                // Invalid response object returned from server
            }
        }
        task.resume()
    }
    
    
    func processRequest(method: String, content: String, statusCode: Int) throws -> Any? {
        guard let data = content.data(using: .utf8) else {
            return nil
        }
        return try JSONSerialization.jsonObject(with: data, options: [])
    }
}
