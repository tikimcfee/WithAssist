//
//  ConversationView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/31/23.
//

import SwiftUI
import OpenAI

struct MaybeHidden: ViewModifier {
    let hidden: Bool
    func body(content: Content) -> some View {
        if hidden { content.hidden() }
        else { content }
    }
}

extension View {
    func doNotDraw(if isHidden: Bool) -> some View {
        modifier(MaybeHidden(hidden: isHidden))
    }
}

struct ConversationView: View, Serialized {
    @ObservedObject var controller: ChatController
    @StateObject var serializer = Serializer()
    
    @State var showOptionsMessage: Chat?
    @State var editMessage: Chat?
    @State var isEditing: Bool = false
    
    init(
        controller: ChatController
    ) {
        self.controller = controller
    }
    
    var body: some View {
        maybeRootView(controller.snapshotState.publishedSnapshot)
    }
    
    @ViewBuilder
    func maybeRootView(_ snapshot: Snapshot?) -> some View {
        if let snapshot {
            ScrollViewReader { proxy in
                List(
                    Array(snapshot.chatMessages.enumerated()),
                    id: \.offset
                ) { (index, message) in
                    ChatRow(
                        message: message,
                        controller: controller,
                        index: index,
                        editMessage: $editMessage,
                        showOptionsMessage: $showOptionsMessage
                    )
                }
                .listStyle(.inset)
            }
        } else {
            Text("Select a converation")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .bold()
        }
    }
}

struct ChatRow: View {
    let message: Chat
    let controller: ChatController
    let index: Int
    
    @Binding var editMessage: Chat?
    @Binding var showOptionsMessage: Chat?
    
    var body: some View {
        HStack {
            let isUser = message.role == .user
            let isAssistant = message.role == .assistant
            
            if isUser { Spacer() }
            
            MessageCellOptionsWrapper(
                editMessage: $editMessage,
                showOptionsMessage: $showOptionsMessage,
                message: message,
                controller: controller
            )
            .border(Color.gray.opacity(0.33), width: 1)
            .padding(
                isUser ? .leading : .trailing,
                96
            )
            .padding(.bottom, 8)
            .tag(index)
            
            if isAssistant { Spacer() }
        }
    }
}

struct MessageCellOptionsWrapper: View, Serialized {
    @Binding var editMessage: Chat?
    @Binding var showOptionsMessage: Chat?
    let message: Chat
    let controller: ChatController
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let messageToEdit = editMessage, messageToEdit.id == message.id {
                editView(message)
            } else if showOptionsMessage?.id == message.id {
                ZStack(alignment: .topTrailing) {
                    MessageCell(message: message)
                    hoverOptions(for: message)
                }
            } else {
                MessageCell(message: message)
            }
        }
        .onHover { isInFrame in
            if isInFrame {
                self.showOptionsMessage = message
            } else {
                self.showOptionsMessage = nil
            }
        }
    }
    
    @ViewBuilder
    func hoverOptions(for message: Chat) -> some View {
        HStack(alignment: .center) {
            EditButton(message: message, editMessage: $editMessage)
                .padding(8)
                .background(Color.gray)
                .clipShape(Circle())
            
            DeleteButton(message: message, controller: controller)
                .padding(8)
                .background(Color.red)
                .clipShape(Circle())
        }
        .padding(8)
    }
    
    @ViewBuilder
    func editView(_ message: Chat) -> some View {
        EditView(
            toEdit: message,
            onComplete: { updated in
                asyncIsolated {
                    await controller.update(message: message, to: updated)
                    editMessage = nil
                }
            },
            onDismiss: {
                showOptionsMessage = nil
                editMessage = nil
            }
        )
    }
}

struct DeleteButton: View, Serialized {
    let message: Chat
    let controller: ChatController
    
    var body: some View {
        Button(
            action: {
                asyncIsolated {
                    print("Deleting: \(message.content.prefix(32))...")
                    await controller.removeMessage(message)
                }
            },
            label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.white)
            }
        )
        .buttonStyle(.plain)
    }
}

struct EditButton: View {
    let message: Chat
    @Binding var editMessage: Chat?
    
    var body: some View {
        Button(
            action: {
                print("Editing: \(message.content.prefix(32))...")
                editMessage = message
            },
            label: {
                Image(systemName: "pencil")
                    .foregroundColor(.green)
            }
        )
        .buttonStyle(.plain)
    }
}

struct MessageCell: View {
    let message: Chat
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(message.role.rawValue)
                .italic()
                .fontWeight(.bold)
                .font(.callout)
            
            Text(message.content)
                .textSelection(.enabled)
                .frame(maxWidth: 600, alignment: .leading)
        }
        .padding(8)
    }
}

extension Chat {
    func updatedContent(of newContent: String) -> Chat {
        Chat(
            role: role,
            content: newContent
        )
    }
}

//                .onReceive($state.publishedSnapshot?.chatMessages) { messages in
//                    if let last = messages?.last {
//                        proxy.scrollTo(last, anchor: .bottom)
//                    }
//                }
//                .onChange(of: snapshot.results.count) { new in
//
//                    if let last = new.chatMessages.first {
//                        print("Scroll to: \(last.content.prefix(32))...")
//
//                    }
//                }
//                .onAppear {
//                    proxy.scrollTo(snapshot.chatMessages.endIndex - 1, anchor: .bottom)
//                    if let last = snapshot.chatMessages.first {
//                        print("Scroll to: \(last.content.prefix(32))...")
//
//                    }
//                }
