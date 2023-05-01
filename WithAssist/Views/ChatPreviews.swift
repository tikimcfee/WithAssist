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
    
    static let snapshot: Snapshot = {
        var snapshot = Snapshot()
        snapshot.results = [
            .init(id: "", object: "", created: .pi, model: .gpt4, choices: [
                .init(index: 0, message: .init(role: .assistant, content: "Hello, this is dog"), finishReason: nil)
            ], usage: .init())
        ]
        return snapshot
    }()
    
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
            chat.snapshotState.setList([snapshot], isPreload: true)
        }
    }
}
