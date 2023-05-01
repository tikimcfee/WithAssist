//
//  EditView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 4/28/23.
//

import Foundation
import RichTextKit
import OpenAI
import SwiftUI

struct EditView: View {
    let toEdit: ChatResult
    let onComplete: (ChatResult) -> Void
    let onDismiss: () -> Void
    
    @State var draft: NSAttributedString
    
    @StateObject private var context = {
        let context = RichTextContext()
        return context
    }()
    
    @Environment(\.colorScheme) var style: ColorScheme
    var foreground: NSColor {
        switch style {
        case .light: return .black
        case .dark: return .white
        @unknown default:
            return .black
        }
    }
    
    var background: NSColor {
        .clear
    }
    
    init(
        toEdit: ChatResult,
        onComplete: @escaping (ChatResult) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.toEdit = toEdit
        self.onComplete = onComplete
        self.onDismiss = onDismiss
        self._draft = State(wrappedValue: NSAttributedString(string: toEdit.firstMessage?.content ?? ""))
    }
    
    var body: some View {
        VStack(alignment: .trailing) {
            RichTextEditor(
                text: $draft,
                context: context,
                format: .plainText,
                viewConfiguration: { component in
                    component.setForegroundColor(to: foreground, at: draft.richTextRange)
                    component.setBackgroundColor(to: background, at: draft.richTextRange)
                }
            )
            .frame(height: 200)
            
            HStack {
                Spacer()
                if !draft.string.isEmpty {
                    LongPressButton(
                        staticColor: .gray.opacity(0.5),
                        holdColor: .green,
                        label: { Text("Save") },
                        action: {
                            if var firstChoice = toEdit.choices.first {
                                firstChoice.message = Chat(
                                    role: firstChoice.message?.role ?? .user,
                                    content: draft.string
                                )
                                
                                var newResult = toEdit
                                newResult.choices[0] = firstChoice
                                onComplete(newResult)
                            }
                        }
                    )
                }
                
                LongPressButton(
                    staticColor: .gray.opacity(0.5),
                    holdColor: .red,
                    label: { Text("Cancel") },
                    action: {
                        onDismiss()
                    }
                )
            }
        }
        .padding(8)
        .background(Color.blue.opacity(0.1))
    }
}

struct LongPressButton<Label: View>: View {
    let staticColor: Color
    let holdColor: Color
    let holdTime: Double = 0.75
    
    @ViewBuilder let label: () -> Label
    let action: () -> Void
    
    var body: some View {
        Button(
            action: { },
            label: label
        )
        .buttonStyle(
            LongPressStyle(
                staticColor: staticColor,
                holdColor: holdColor,
                holdTime: holdTime,
                action: action
            )
        )
    }
}

struct LongPressStyle: ButtonStyle {
    @GestureState var isDetectingLongPress = false
    @State var completedLongPress = false
    
    let staticColor: Color
    let holdColor: Color
    let holdTime: Double
    let action: () -> Void
    
    init(
        staticColor: Color,
        holdColor: Color,
        holdTime: Double,
        action: @escaping () -> Void
    ) {
        self.staticColor = staticColor
        self.holdColor = holdColor
        self.holdTime = holdTime
        self.action = action
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .simultaneousGesture(
                gesture(configuration)
            )
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                pressedBackground(configuration)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4.0))
            .animation(
                .linear(duration: isDetectingLongPress ? holdTime : 0.125),
                value: isDetectingLongPress
            )
    }
    
    
    func gesture(_ configuration: Configuration) -> some Gesture {
        LongPressGesture(minimumDuration: holdTime)
            .updating($isDetectingLongPress) { currentState, gestureState, transaction in
                gestureState = currentState
            }
            .onEnded { finished in
                completedLongPress = finished
                action()
            }
    }
    
    @ViewBuilder
    func pressedBackground(_ configuration: Configuration) -> some View {
        isDetectingLongPress
            ? holdColor
            : staticColor
    }
}
