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
                SnapshotListView(
                    currentSnapshot: $chatController.snapshotState.currentSnapshot
                )
                .environmentObject(chatController.snapshotState)
            },
            content: {
                if let current = chatController.snapshotState.currentSnapshot {
                    mainInteractionsView(current)
                        .padding()
                }
                
            },
            detail: {
                if let current = chatController.snapshotState.currentSnapshot {
                    conversationView(current)
                        .toolbar {
                            ToolbarItem(placement:  .primaryAction) {
                                newConversationView
                            }
                        }
                }
            }
        )
        .navigationSplitViewStyle(.balanced)
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
    func mainInteractionsView(_ snapshot: Snapshot) -> some View {
        InteractionsView(
            isLoading: isLoading,
            snapshot: snapshot,
            controller: chatController
        )
    }
    
    @ViewBuilder
    func conversationView(_ snapshot: Snapshot) -> some View {
        ConversationView(snapshot: snapshot)
    }
}
