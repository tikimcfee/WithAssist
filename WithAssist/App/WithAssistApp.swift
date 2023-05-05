//
//  WithAssistApp.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/18/23.
//

import SwiftUI

// The sins of global state.
class AppState {
    static let global = AppState()
    private init() { }
    
    private lazy var client = ClientStore.defaultClient
    private lazy var chatController = ClientStore.defaultChat
    lazy var defaultStore = ClientStore(client: client, chat: chatController)
    
    lazy var defaultMagi = Magi(name: "First Magi", controller: {
        let controller = ChatController(openAI: client)
        return controller
    }())
    lazy var defaultStage = {
        let magi = defaultMagi
        let stage = MagiEntityStage(magi: magi)
        return stage
    }()
}

@main
struct WithAssistApp: App {
    @ObservedObject var clientStore: ClientStore = AppState.global.defaultStore
    
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
