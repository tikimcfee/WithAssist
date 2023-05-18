//  WithAssist
//
//  Created on 5/18/23.
//  

import Foundation

private let JSON_ENCODER = JSONEncoder()
private let JSON_DECODER = JSONDecoder()

class StreamingSession<ResultType: Codable>: NSObject, Identifiable, URLSessionDelegate, URLSessionDataDelegate {
    var onReceiveContent: ((StreamingSession, ResultType) -> Void)?
    var onProcessingError: ((StreamingSession, Error) -> Void)?
    var onComplete: ((StreamingSession, Error?) -> Void)?
    
    private let streamingCompletionMarker = "[DONE]"
    private let urlRequest: URLRequest
    
    private let configure: () -> URLSessionConfiguration
    private lazy var urlSession: URLSession = {
        URLSession(
            configuration: configure(),
            delegate: self,
            delegateQueue: nil
        )
    }()
    
    var incompleteJson: String?
     
    init(
        urlRequest: URLRequest,
        configure: @escaping () -> URLSessionConfiguration
    ) {
        self.urlRequest = urlRequest
        self.configure = configure
    }
    
    func perform() {
        urlSession
            .dataTask(with: self.urlRequest)
            .resume()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        onComplete?(self, error)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let stringContent = String(data: data, encoding: .utf8) else {
            onProcessingError?(self, StreamingError.unknownContent)
            return
        }
        
        print(">>>>>>>>>>")
        print(stringContent.prefix(32))
        print("<<<<<<<<<<")
        if stringContent.localizedCaseInsensitiveContains("event: ping") {
            print("~~~ Skipping ping event ~~~")
            return
        }
        
        let jsonObjects = stringContent
            .components(separatedBy: "data:")
            .filter { $0.isEmpty == false }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        guard jsonObjects.isEmpty == false else {
            onProcessingError?(self, StreamingError.emptyContent)
            return
        }
        
        for jsonObject in jsonObjects {
            guard jsonObject != streamingCompletionMarker else {
                print("[stream] found completion")
                onComplete?(self, nil)
                return
            }
            
            let jsonContent: String
            if let incompleteJson {
                jsonContent = incompleteJson + jsonObject
                print("[stream] appending incomplete json...")
            } else {
                jsonContent = jsonObject
            }
            
            guard let jsonData = jsonContent.data(using: .utf8) else {
                print("[stream] data processing error")
                onProcessingError?(self, StreamingError.unknownContent)
                return
            }
            do {
                let decoder = JSON_DECODER
                let object = try decoder.decode(ResultType.self, from: jsonData)
                print("[stream] found content")
                onReceiveContent?(self, object)
                incompleteJson = nil
            } catch {
                print("[stream] decoding error, testing incomplete json")
                if !jsonContent.hasSuffix("}") {
                    print("[stream] setting incomplete json...")
                    incompleteJson = incompleteJson?.appending(jsonContent) ?? jsonContent
                }
//                else {
//                    onProcessingError?(self, error)
//                }
            }
        }
    }
}

extension StreamingSession {
    enum StreamingError: Error {
        case unknownContent
        case emptyContent
    }
}

extension Encodable {
    func asData() -> Data? {
        try? JSON_ENCODER.encode(self)
    }
}
