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
    @Published var optionsTarget: ChatResult?
    @Published var editTarget: ChatResult?
    
    func showOptions(for result: ChatResult?) -> Bool {
        let show = optionsTarget?.id == result?.id
        return show
    }
    
    func showEdit(for result: ChatResult?) -> Bool {
        let show = editTarget?.id == result?.id
        return show
    }
}

struct ConversationView: View, Serialized {
    @ObservedObject var controller: ChatController
    @StateObject var serializer = Serializer()
    @StateObject var actionState = ActionState()
    
    init(
        controller: ChatController
    ) {
        self.controller = controller
    }
    
    var body: some View {
        maybeRootView(controller.snapshotState.publishedSnapshot)
    }
    
    @ViewBuilder
    func platformList(for snapshot: Snapshot?) -> some View {
        #if os(iOS)
        ScrollView {
            LazyVStack {
                listBody(for: snapshot)
            }
            .padding()
        }
        #else
        List {
            listBody(for: snapshot)
        }
        .listStyle(.plain)
        #endif
    }
    
    @ViewBuilder
    func listBody(for snapshot: Snapshot?) -> some View {
        if let snapshot {
            ForEach(
                snapshot.results
            ) { result in
                ChatRow(
                    result: result,
                    controller: controller
                )
                .tag(result.id)
                .environmentObject(actionState)
                .listRowSeparator(.hidden)
            }
        }
    }
    
    @ViewBuilder
    func maybeRootView(_ snapshot: Snapshot?) -> some View {
        if let snapshot {
            ScrollViewReader { proxy in
                platformList(for: snapshot)
                    .onReceive(controller.snapshotState.$publishedSnapshot) { [proxy] snapshot in
                        guard let snapshot else { return }
                        print("Scroll to new: \(snapshot.id)")
                        if let id = snapshot.results.last?.id {
                            proxy.scrollTo(id, anchor: .bottom)
                        }
                    }
                    .onChange(of: snapshot.results.count) { [proxy] newCount in
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
            .frame(maxWidth: 600, alignment: .leading)
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
    }
    
    @ViewBuilder
    func rootBody() -> some View {
        ZStack(alignment: .topTrailing) {
            if actionState.showEdit(for: result) {
                editView(result)
            }
            else {
                MessageCell(result: result)
                if actionState.showOptions(for: result) {
                    hoverOptions(for: result)
                }
            }
        }
        .onHover { isInFrame in
            print("Hover toggle: \(result.id) -> \(isInFrame)")
            if isInFrame {
                actionState.optionsTarget = result
            } else {
                actionState.optionsTarget = nil
            }
        }
        #if os(iOS)
        .background(Color.gray.opacity(0.02))
        .onTapGesture {
            if actionState.optionsTarget?.id != result.id {
                actionState.optionsTarget = result
            } else {
                actionState.optionsTarget = nil
            }
        }
        #endif
    }
    
    @ViewBuilder
    func hoverOptions(for result: ChatResult) -> some View {
        HStack(alignment: .center, spacing: 0) {
            EditButton(result: result)
                .padding(.horizontal, 4)
            
            DeleteButton(result: result, controller: controller)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 8)
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
                    .resizable()
                    .frame(width: 14, height: 14)
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
                    .resizable()
                    .frame(width: 14, height: 14)
                    .foregroundColor(.green)
            }
        )
        .padding()
        .buttonStyle(.plain)
    }
}

struct MessageCell: View {
    let result: ChatResult
    
    var body: some View {
        if let message = result.firstMessage {
            VStack(alignment: .leading, spacing: 12.0) {
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
