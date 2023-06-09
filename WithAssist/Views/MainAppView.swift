//
//  MainAppView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/31/23.
//

import SwiftUI
import OpenAI

struct MainAppView: View {
    @ObservedObject var chatController: ChatController
    
    @State var path: NavigationPath = NavigationPath()
    
    var body: some View {
        #if os(macOS)
        chatBody
        #else
        compactBody
        #endif
    }
    
    @ViewBuilder
    var compactBody: some View {
        NavigationStack(path: $path) {
            listView()
                .toolbar { ToolbarItem { newConversationView } }
                .navigationDestination(for: Snapshot.self) { snapshot in
                    mainInteractionsView()
                        .navigationTitle(snapshot.name)
                }
        }
        .onReceive(chatController.snapshotState.$publishedSnapshot) {
            if let snapshot = $0 {
                path = NavigationPath([snapshot])
            }
            
        }
    }
    
    @ViewBuilder
    var chatBody: some View {
        NavigationSplitView(
            sidebar: {
                listView()
            },
            detail: {
                mainInteractionsView()
                    .toolbar {
                        ToolbarItem {
                            newConversationView
                        }
                    }
            }
        )
    }
    
    @ViewBuilder
    var tripleColumnBody: some View {
        NavigationSplitView(
            sidebar: {
                listView()
            },
            content: {
                mainInteractionsView()
                    .padding()
            },
            detail: {
                conversationView()
            }
        )
        .navigationSplitViewStyle(.automatic)
    }
    
    @ViewBuilder
    var newConversationView: some View {
        Button(
            action: {
                chatController.controlNewConversation()
            },
            label: {
                Label("New Conversation", systemImage: "plus.circle")
                    .labelStyle(.titleAndIcon)
            }
        )
    }
    
    @ViewBuilder
    func waitingView() -> some View {
        Text("Waiting for a thing to happen")
    }
    
    @ViewBuilder
    func mainInteractionsView() -> some View {
        InteractionsView(
            controller: chatController
        )
    }
    
    @ViewBuilder
    func conversationView() -> some View {
        ConversationView(
            controller: chatController
        )
    }
    
    @ViewBuilder
    func listView() -> some View {
        SnapshotListView()
            .environmentObject(chatController)
            .environmentObject(chatController.snapshotState)
    }
}
