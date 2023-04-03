//
//  SnapshotListView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/29/23.
//

import SwiftUI
import OpenAI

struct SnapshotListView: View {
    @EnvironmentObject var store: ChatController.SnapshotState
    @State var selection: Int = 0
    
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
            Button(
                action: {
                    selection = index
                },
                label: {
                    cell(snapshot)
                }
            )
            .buttonStyle(.plain)
            .background(
                snapshot.id == store.currentSnapshot?.id
                ? .blue
                : .clear
            )
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 4.0))
        }
        .onChange(of: selection) {
            store.currentIndex = $0
        }
        #endif

    }
    
    @ViewBuilder
    func cell(_ snapshot: Snapshot) -> some View {
        Text(snapshot.name)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    }
}
