//  WithAssist
//
//  Created on 5/17/23.
//


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
        receiver: @escaping ([String: Any]?) -> Void
    ) {
        let urlRequest = request(method: "POST", path: "/v1/complete", params: params)
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
    
    func parseJSON(json: Substring) throws -> Any? {
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

extension Dictionary where Key == String, Value == Any {
    var maybeCompletion: String? {
        self["completion"] as? String
    }
    
    var maybeStop: String? {
        self["stop"] as? String
    }
}
