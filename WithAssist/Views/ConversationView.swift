//
//  ConversationView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/31/23.
//

import SwiftUI
import OpenAI

struct ConversationView: View, Serialized {
    @ObservedObject var store: ChatController
    @ObservedObject var state: ChatController.SnapshotState
    @StateObject var serializer = Serializer()
    
    @State var showOptionsMessage: OpenAI.Chat?
    @State var editMessage: OpenAI.Chat?
    @State var isEditing: Bool = false
    
    init(
        store: ChatController
    ) {
        self.store = store
        self._state = ObservedObject(initialValue: store.snapshotState)
    }
    
    var snapshot: Snapshot? {
        store.snapshotState.currentSnapshot
    }
    
    var body: some View {
        if let snapshot {
            ScrollViewReader { proxy in
                List(snapshot.chatMessages.reversed()) { message in
                    messageCellOptionsWrapper(message)
                        .border(Color.gray.opacity(0.33), width: 1)
                        .tag(message.id)
                }
                .listStyle(.inset)
                .onChange(of: snapshot.results) { _ in
                    if let last = snapshot.chatMessages.last {
                        print("Scroll to: \(last.id)")
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func messageCellOptionsWrapper(_ message: OpenAI.Chat) -> some View {
        ZStack(alignment: .topTrailing) {
            if let messageToEdit = editMessage, messageToEdit.id == message.id {
                EditView(
                    toEdit: messageToEdit,
                    currentText: messageToEdit.content,
                    onComplete: { updated in
                        asyncMain {
                            await store.update(
                                message: message,
                                to: updated
                            )
                            editMessage = nil
                        }
                    },
                    onDismiss: {
                        showOptionsMessage = nil
                        editMessage = nil
                    }
                )
            } else if showOptionsMessage?.id == message.id {
                messageCell(message)
                hoverOptions(for: message)
            } else {
                messageCell(message)
            }
        }
        .onHover { isInFrame in
            if isInFrame {
                self.showOptionsMessage = message
            } else {
                self.showOptionsMessage = nil
            }
            
        }
//        .sheet(item: $editMessage) { toEdit in
//            EditView(
//                toEdit: toEdit,
//                currentText: toEdit.content,
//                onComplete: { updated in
//                    asyncMain {
//                        await store.updateMessageInstance(updated)
//                        editMessage = nil
//                    }
//                },
//                onDismiss: {
//                    showOptionsMessage = nil
//                    editMessage = nil
//                }
//            )
//        }
    }
    
    @ViewBuilder
    func hoverOptions(for message: OpenAI.Chat) -> some View {
        VStack(alignment: .trailing) {
            Button(
                action: {
                    asyncMain {
                        print("Deleting: \(message.content.prefix(32))...")
                        await store.removeMessage(message)
                    }
                },
                label: {
                    Label("Delete", systemImage: "minus.circle.fill")
                }
            )
            .foregroundColor(.white)
            
            Button(
                action: {
                    print("Editing: \(message.content.prefix(32))...")
                    editMessage = message
                },
                label: {
                    Label("Edit", systemImage: "pencil")
                }
            )
            .foregroundColor(.white)
        }
        .padding(8)
        .background(Color.gray)
    }
    
    @ViewBuilder
    func messageCell(_ message: OpenAI.Chat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(message.role)
                .italic()
                .fontWeight(.light)
                .font(.caption)
            
            Text(message.content)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
    }
}

struct EditView: View {
    let toEdit: OpenAI.Chat
    @State var currentText: String
    let onComplete: (OpenAI.Chat) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .trailing) {
            TextField("Enter new content", text: $currentText, axis: .vertical)
            
            if !currentText.isEmpty {
                Button("Save") {
                    onComplete(
                        toEdit.updatedContent(of: currentText)
                    )
                }
            }
            
            Button("Cancel") {
                onDismiss()
            }
        }
        .padding(8)
        .background(Color.blue.opacity(0.1))
    }
}

extension OpenAI.Chat {
    func updatedContent(of newContent: String) -> OpenAI.Chat {
        OpenAI.Chat(
            role: role,
            content: newContent
        )
    }
}
