//
//  WithAssistApp.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/18/23.
//

import SwiftUI

typealias Store = CodableFileStorage<SnapshotStore>
typealias StoreItem = CodableFileStorage<SnapshotStore>.StorageState

@main
struct WithAssistApp: App {
    @ObservedObject
    private var userSettingsStorage =
        CodableFileStorage<SnapshotStore>(
            storageObject: .empty,
            appFile: .defaultSnapshot
        )
    
    @State
    var client = Self.makeClient()
    
    var body: some Scene {
        WindowGroup {
            MainAppView(
                client: client.chat,
                requestCurrentStateSave: {
                    doSave()
                },
                requestNewConversation: {
                    doAdd()
                }
            )
            .environmentObject(userSettingsStorage)
            .overlay(
                overlayView(userSettingsStorage.state)
            )
            .task {
                await doLoad()
            }
            .onDisappear {
                doSave()
            }
        }
    }
    
    func doLoad() async {
        await userSettingsStorage.load()
        if let snapshot = userSettingsStorage.state.maybeValue?.snapshots.last {
            print("loaded \(snapshot.id)")
            client.chat.snapshot.current = snapshot
        }
    }
    
    func doSave() {
        Task {
            await userSettingsStorage.updateValue {
                $0?.update(client.chat.snapshot.current)
            }
        }
    }
    
    func doAdd() {
        Task {
            await userSettingsStorage.updateValue {
                $0?.setNewSnapshotAsCurrent(in: client.chat)
            }
        }
    }
    
    @ViewBuilder
    private func overlayView(_ state: StoreItem) -> some View {
        switch state {
        case .idle(_):
            EmptyView()
            
        case .loading:
            ProgressView()
            
        case .loaded(_):
            EmptyView()
            
        case .saving:
            ProgressView()

        case .error(let error):
            ZStack(alignment: .bottom) {
                Text(String(describing: error))
                    .padding()
                    .background(Color.red.opacity(0.67))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .padding(32)
        }
    }

    func updateState(_ state: CodableFileStorage<Snapshot>.StorageState) {
        switch state {
        case .idle(value: let value):
            client.chat.snapshot.current = value()
            
        case .loading:
            break
            
        case .loaded(value: let value):
            client.chat.snapshot.current = value
            
        case .saving:
            break
            
        case .error(let error):
            print(error)
        }
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
