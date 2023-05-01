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

class ActionState: ObservableObject {
    var optionsTarget: ChatResult?
    var editTarget: ChatResult?
    
    func showOptions(for result: ChatResult?) -> Bool {
        optionsTarget?.id == result?.id
    }
    
    func showEdit(for result: ChatResult?) -> Bool {
        editTarget?.id == result?.id
    }
}

struct ConversationView: View, Serialized {
    @ObservedObject var controller: ChatController
    @StateObject var serializer = Serializer()
    @StateObject var hoverState = ActionState()
    
    init(
        controller: ChatController
    ) {
        self.controller = controller
    }
    
    var body: some View {
        maybeRootView(controller.snapshotState.publishedSnapshot)
            .environmentObject(hoverState)
    }
    
    @ViewBuilder
    func maybeRootView(_ snapshot: Snapshot?) -> some View {
        if let snapshot {
            ScrollViewReader { proxy in
                List {
//                ScrollView {
//                    LazyVStack {
                        ForEach(
                            snapshot.results
                        ) { result in
                            ChatRow(
                                result: result,
                                controller: controller
                            )
                            .tag(result.id)
                        }
//                    }
                }
                .listStyle(.plain)
                .onReceive(controller.snapshotState.$publishedSnapshot) { snapshot in
                    guard let snapshot else { return }
                    print("Scroll to new: \(snapshot.id)")
                    if let id = snapshot.results.last?.id {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
                .onChange(of: snapshot.results.count) { newCount in
                    print("Scroll to count: \(newCount)")
                    if let id = snapshot.results.last?.id {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
        } else {
            Text("Select a converation")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .bold()
        }
    }
}

let rolePad: CGFloat = {
    #if os(iOS)
    16
    #else
    96
    #endif
}()

struct ChatRow: View {
    let result: ChatResult
    let controller: ChatController
    
    var body: some View {
        HStack {
            let isUser = result.firstMessage?.role == .user
            let isAssistant = result.firstMessage?.role == .assistant
            
            if isUser { Spacer() }
            
            MessageCellOptionsWrapper(
                result: result,
                controller: controller
            )
            .border(Color.gray.opacity(0.33), width: 1)
            .padding(
                isUser ? .leading : .trailing,
                rolePad
            )
            .padding(.bottom, 8)
            .tag(result.id)
            
            if isAssistant { Spacer() }
        }
    }
}

struct MessageCellOptionsWrapper: View, Serialized {
    let result: ChatResult
    let controller: ChatController
    @EnvironmentObject var actionState: ActionState
    
    var body: some View {
        rootBody()
            .onHover { isInFrame in
                if isInFrame {
                    actionState.optionsTarget = result
                } else {
                    actionState.optionsTarget = nil
                }
            }
    }
    
    @ViewBuilder
    func rootBody() -> some View {
        if actionState.showEdit(for: result) {
            editView(result)
        }
        else if actionState.showOptions(for: result) {
            ZStack(alignment: .topTrailing) {
                MessageCell(result: result)
                hoverOptions(for: result)
            }
            #if os(iOS)
                .background(Color.gray.opacity(0.02))
                .onTapGesture {
                    if showOptions {
                        showOptionsResult = result
                    } else {
                        showOptionsResult = nil
                    }
                }
            #endif
        }
        else {
            MessageCell(result: result)
            #if os(iOS)
                .background(Color.gray.opacity(0.02))
                .onTapGesture {
                    if showOptions {
                        showOptionsResult = result
                    } else {
                        showOptionsResult = nil
                    }
                }
            #endif
        }
    }
    
    @ViewBuilder
    func hoverOptions(for result: ChatResult) -> some View {
        HStack(alignment: .center) {
            EditButton(result: result)
                .padding(8)
                .clipShape(Circle())
            
            DeleteButton(result: result, controller: controller)
                .padding(8)
                .clipShape(Circle())
        }
        .padding(8)
    }
    
    @ViewBuilder
    func editView(_ result: ChatResult) -> some View {
        EditView(
            toEdit: result,
            onComplete: { updated in
                asyncIsolated {
                    await controller.updateResult(updated)
                    actionState.editTarget = nil
                    actionState.optionsTarget = nil
                }
            },
            onDismiss: {
                actionState.editTarget = nil
                actionState.optionsTarget = nil
            }
        )
        .padding(
            result.firstMessage?.role == .user ? .leading : .trailing,
            rolePad
        )
    }
}

struct DeleteButton: View, Serialized {
    let result: ChatResult
    let controller: ChatController
    
    var body: some View {
        LongPressButton(
            staticColor: .red.opacity(0.12),
            holdColor: .red,
            label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            },
            action: {
                asyncIsolated {
                    await controller.removeResult(result)
                }
            }
        )
    }
}

struct EditButton: View {
    let result: ChatResult
    @EnvironmentObject var actionState: ActionState
    
    var body: some View {
        Button(
            action: {
                actionState.editTarget = result
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
    let result: ChatResult
    
    var body: some View {
        if let message = result.firstMessage {
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
        else {
            Text(".. no content")
                .font(.subheadline)
                .italic()
                .padding(8)
        }
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
