//
//  WithAssistApp.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/18/23.
//

import SwiftUI

@main
struct WithAssistApp: App {
    @State
    var clientStore: ClientStore = Self.makeClient()
    
    @Environment(\.scenePhase)
    private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            MainAppView(
                chatController: clientStore.chat
            )
            .task {
                doLoad()
            }
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .inactive:
                    print("[scene phase] now inactive; saving")
                    doSave()
                
                default:
                    break
                }
            }
        }
    }
    
    func doSave() {
        clientStore.chat.saveManual()
    }
    
    func doLoad() {
        clientStore.chat.loadController()
    }
    
    static func makeClient() -> ClientStore {
        let api = ClientStore.makeAPIClient()
        let chat = ChatController(openAI: api)
        
        let client = ClientStore(
            client: api,
            chat: chat
        )
        
        return client
    }
}
