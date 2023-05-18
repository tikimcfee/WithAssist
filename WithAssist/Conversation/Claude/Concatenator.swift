//  WithAssist
//
//  Created on 5/18/23.
//  

import Foundation

class Concatenator {
    func concatenateAt(
        directory: String
    ) -> String {
        let filePaths = collectFiles(directory: directory)
        let concatenatedText = concatenate(paths: filePaths)
        let pattern = "(\\\\n\\\\nHuman:|\\\\n\\\\nAssistant:)"
        let replacedVersion = concatenatedText.replacingMatches(
            pattern: pattern,
            replace: replaceKeywordMatch(_:)
        )
        return replacedVersion
    }
    
    private func replaceKeywordMatch(_ match: String) -> String? {
        print("found: \(match)")
        if match.contains("Human") {
            return "_H: "
        } else if match.contains("Assistant") {
            return "_A: "
        } else {
            return nil
        }
    }
    
    func collectFiles(
        directory: String
    ) -> [URL] {
        let rootUrl = URL(
            filePath: directory,
            directoryHint: .isDirectory
        )
        guard let enumerator = FileManager.default.enumerator(
            at: rootUrl,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            print("[\(#function)] - no enumerator")
            return []
        }
        
        let keys: Set<URLResourceKey> = [.isDirectoryKey]
        let lazyPaths = enumerator.lazy
            .compactMap { $0 as? URL }
            .filter {
                (try? $0.resourceValues(forKeys: keys))?
                    .isDirectory == false
            }
            .filter {
                $0.lastPathComponent.hasSuffix("swift")
            }
        return Array(lazyPaths)
    }
    
    
    func concatenate(paths: [URL]) -> String {
        let result = paths.reduce(into: DataConcat()) { result, path in
            result.append(getContents(of: path))
        }
        return result.resultString
    }
    
    func getContents(of url: URL) -> Data? {
        do {
            let data = try Data(contentsOf: url)
            return data
        } catch {
            print(error)
            return nil
        }
    }
}

struct DataConcat {
    var allData: Data = Data()
    
    mutating func append(_ data: Data?) {
        if let data { allData.append(data) }
    }
    
    var resultString: String {
        guard !allData.isEmpty else { return "" }
        let maybeResult = String(data: allData, encoding: .utf8)
        return maybeResult ?? ""
    }
}
