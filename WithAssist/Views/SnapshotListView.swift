//
//  SnapshotListView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/29/23.
//

import SwiftUI
import OpenAI

struct SnapshotListView: View {
    @EnvironmentObject var store: CodableFileStorage<SnapshotStore>
    @Binding var currentSnapshot: Snapshot
    
    var body: some View {
        if let store = store.state.maybeValue {
            List(store.snapshots) { snapshot in
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
                    snapshot.id == currentSnapshot.id
                    ? Color.gray.opacity(0.33)
                    : Color.clear
                )
            }
        } else {
            EmptyView()
        }
    }
}
