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
    @Binding var currentSnapshot: Snapshot?
    
    var body: some View {
        List(store.allSnapshots.list) { snapshot in
            Button(
                action: {
                    currentSnapshot = snapshot
                },
                label: {
                    Text(snapshot.name)
                }
            )
            .buttonStyle(.plain)
            .listRowBackground(
                currentSnapshot != nil
                && snapshot.id == currentSnapshot?.id
                ? Color.gray.opacity(0.33)
                : Color.clear
            )
        }
    }
}
