//
//  WithAssistApp.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/18/23.
//

import SwiftUI

@main
struct WithAssistApp: App {
    @State var client = AsyncClient()
    
    var body: some Scene {
        WindowGroup {
            ChatConversationView(
                client: client.chat
            )
        }
    }
}
