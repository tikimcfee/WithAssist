//
//  SnapshotListView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/29/23.
//

import SwiftUI
import OpenAI

struct SnapshotListView: View, Serialized {
    @EnvironmentObject var controller: ChatController
    @EnvironmentObject var store: ChatController.SnapshotState
    @State var selection: Int = 0
    
    @StateObject var serializer = Serializer()
    
    @State var deleting = false
    @State var deleteTarget: Snapshot?
    
    var body: some View {
        #if os(iOS)
        ScrollView {
            LazyVStack(alignment: .leading) {
                ForEach(
                    Array(store.allSnapshots.list.enumerated()),
                    id: \.element.id
                ) { (index, snapshot) in
                    Button(
                        action: {
                            selection = index
                        },
                        label: {
                            cell(snapshot)
                        }
                    ).buttonStyle(.bordered)
                }
            }
        }
        #else
        List(
            Array(store.allSnapshots.list.enumerated()),
            id: \.element.id,
            selection: $selection
        ) { (index, snapshot) in
            listItem(index, snapshot)
        }
        .onChange(of: selection) {
            store.currentIndex = $0
        }
        .confirmationDialog(
            "Remove conversation?",
            isPresented: $deleting,
            presenting: deleteTarget,
            actions: { target in
                Button(
                    role: .destructive,
                    action: {
                        asyncIsolated {
                            await controller.removeSnapshot(target)
                        }
                    },
                    label: {
                        Text("Delete '\(target.name)'")
                    }
                )
            },
            message: { target in
                let prefix: String = String(target.chatMessages.first?.content.prefix(128) ?? "")
                Text("First message:\n \(prefix)...")
                    .italic()
            }
        )
        #endif

    }
    
    @ViewBuilder
    func listItem(_ index: Int, _ snapshot: Snapshot) -> some View {
        HStack(alignment: .center) {
            Button(
                action: {
                    deleting = true
                    deleteTarget = snapshot
                },
                label: {
                    Image(systemName: "x.square.fill")
                        .foregroundColor(.red)
                }
            )
            .buttonStyle(.plain)
            
            Button(
                action: {
                    selection = index
                },
                label: {
                    cell(snapshot)
                }
            )
            .buttonStyle(.plain)
        }
        .padding()
        .border(Color.gray, width: 0.5)
        .background(
            snapshot.id == store.currentSnapshot?.id
                ? .blue.opacity(0.1415)
                : .clear
        )
    }
    
    @ViewBuilder
    func cell(_ snapshot: Snapshot) -> some View {
        Text(snapshot.name)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    }
}
