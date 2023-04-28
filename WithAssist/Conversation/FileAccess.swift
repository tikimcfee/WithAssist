//  WithAssist
//
//  Created on 4/10/23.
//  

import Foundation
import SwiftUI

struct GlobalFileSelector {
    
    private static func _requestSystemUrl(
        for name: String,
        completion: @escaping (URL?) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        
        panel.resolvesAliases = true
        
        panel.prompt = "Save '\(name)'"
        panel.title = "Select directory to save to"
        panel.begin { result in
            if result == .OK, let url = panel.url {
                completion(url)
            } else {
                completion(nil)
            }
        }
    }
    
    static func requestSystemUrl(
        for name: String,
        completion: @escaping (URL?) -> Void
    ) {
        DispatchQueue.main.async {
            _requestSystemUrl(for: name, completion: completion)
        }
    }
}
