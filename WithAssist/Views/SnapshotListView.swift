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
        List(
            Array(store.allSnapshots.list.enumerated()),
            id: \.element.id,
            selection: $selection
        ) { (index, snapshot) in
            Text(snapshot.name)
                .frame(minWidth: 96, alignment: .leading)
//                .listRowBackground(
//                    index == store.currentIndex
//                        ? Color.gray.opacity(0.33)
//                        : Color.clear
//                )
                .tag(index)
        }
        .onChange(of: selection) {
            store.currentIndex = $0
        }
    }
}
