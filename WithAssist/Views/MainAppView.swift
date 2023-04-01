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
    @State var isLoading: Bool = false
    
    var body: some View {
        NavigationSplitView(
            sidebar: {
                SnapshotListView()
                    .toolbar {
                        ToolbarItem(placement:  .primaryAction) {
                            newConversationView
                        }
                    }
                    .environmentObject(chatController.snapshotState)
            },
            content: {
                mainInteractionsView()
                    .padding()
            },
            detail: {
                if let current = chatController.snapshotState.currentSnapshot {
                    conversationView(current)
                }
            }
        )
        .navigationSplitViewStyle(.automatic)
    }
    
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
            isLoading: isLoading,
            controller: chatController
        )
    }
    
    @ViewBuilder
    func conversationView(_ snapshot: Snapshot) -> some View {
        ConversationView(snapshot: snapshot)
    }
}
