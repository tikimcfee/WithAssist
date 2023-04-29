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
    @EnvironmentObject var state: ChatController.SnapshotState
    
    @StateObject var serializer = Serializer()
    
    @State var deleting = false
    @State var deleteTarget: Snapshot?
    
    var body: some View {
        rootBody()
    }
    
    func rootBody() -> some View {
        @ViewBuilder
        func delete(_ target: Snapshot) -> some View {
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
        }
        
        return platformBody()
            .confirmationDialog(
                "Remove conversation?",
                isPresented: $deleting,
                presenting: deleteTarget,
                actions: { target in
                    delete(target)
                },
                message: { target in
                    let prefix: String = String(target.chatMessages.first?.content.prefix(128) ?? "")
                    Text("First message:\n \(prefix)...")
                        .italic()
                }
            )
    }
    
    @ViewBuilder
    func platformBody() -> some View {
        #if os(iOS)
        compactBody()
        #else
        desktopBody()
        #endif
    }
    
    @ViewBuilder
    func compactBody() -> some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                ForEach(
                    Array(state.allSnapshots.list.enumerated()),
                    id: \.element.id
                ) { (index, snapshot) in
                    listItem(index, snapshot)
                }
            }
        }
    }
    
    #if os(macOS)
    @ViewBuilder
    func desktopBody() -> some View {
        List(
            Array(state.allSnapshots.list.enumerated()),
            id: \.element.id,
            selection: $selection
        ) { (index, snapshot) in
            listItem(index, snapshot)
        }
    }
    #endif
    
    @ViewBuilder
    func listItem(
        _ index: Int,
        _ snapshot: Snapshot
    ) -> some View {
        HStack(alignment: .center) {
            cell(snapshot)
            delete(snapshot)
        }
        .padding()
        .border(Color.gray, width: 0.5)
        .background(
            snapshot.id == controller.snapshotState.publishedSnapshot?.id
                ? .blue.opacity(0.1415)
                : .gray.opacity(0.1) // needs some visible value for tap target
        )
        .onTapGesture {
            controller.snapshotState.currentIndex = index
        }
    }
    
    @ViewBuilder
    func delete(_ snapshot: Snapshot) -> some View {
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
    }
    
    @ViewBuilder
    func cell(_ snapshot: Snapshot) -> some View {
        Text(snapshot.name)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
