//
//  ContentView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/18/23.
//

import SwiftUI
import OpenAI
import Combine

struct ContentView_Previews: PreviewProvider {
    static let openAI = ClientStore.makeAPIClient()
    
    static let snapshot = Snapshot(
        chatMessages: [
            .init(role: .system, content: "Hello, this is dog"),
            .init(role: .user, content: "Hello dog, good borks?"),
            .init(role: .assistant, content: "Very yes much always")
        ]
    )
    
    static let chat: ChatController = {
        let controller = ChatController(
            openAI: openAI
        )
        return controller
    }()
    
    static let client: ClientStore = {
        let client = ClientStore(
            chat: chat
        )
        
        return client
    }()
    
    static var previews: some View {
        MainAppView(
            chatController: chat
        ).task {
            Task {
                await chat.snapshotState.setList([snapshot])
            }
        }
    }
}
