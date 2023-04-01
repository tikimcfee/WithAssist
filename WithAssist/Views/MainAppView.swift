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
        .toolbar {
            ToolbarItem(placement:  .primaryAction) {
                newConversationView
            }
        }
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
    func conversationView() -> some View {
        ConversationView()
            .environmentObject(chatController.snapshotState)
    }
    
    @ViewBuilder
    func listView() -> some View {
        SnapshotListView()
            .environmentObject(chatController.snapshotState)
    }
}
