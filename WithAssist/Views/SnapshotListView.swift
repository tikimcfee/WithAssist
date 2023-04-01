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
    
    var body: some View {
        List(
            Array(store.allSnapshots.list.enumerated()),
            id: \.element.id
        ) { (index, snapshot) in
            Button(
                action: {
                    store.currentIndex = index
                },
                label: {
                    Text(snapshot.name)
                }
            )
            .buttonStyle(.plain)
            .listRowBackground(
                index == store.currentIndex
                    ? Color.gray.opacity(0.33)
                    : Color.clear
            )
        }
    }
}
