//
//  SettingsView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/27/23.
//

import SwiftUI
import OpenAI

struct SettingsView: View {
    @ObservedObject var chat: ChatController
    
    var body: some View {
        List {
            textBody()
            modelPickerView()
            sliderBody()
        }
        .listStyle(.sidebar)
    }
    
    @ViewBuilder
    func textBody() -> some View {
        TextField("User", text: $chat.paramState.current.user)
            .underline()
    }
    
    @ViewBuilder
    func modelPickerView() -> some View {
        Picker("GPT Model", selection: $chat.paramState.current.chatModel) {
            ForEach(Model.allCases) { model in
                Text(model.rawValue)
                    .tag(model)
            }
        }
    }
    
    @ViewBuilder
    func sliderBody() -> some View {
        ToggleSlider(
            name: "Tokens",
            use: .constant(true),
            value: .init(
                get: { Double(chat.paramState.current.maxTokens) },
                set: { chat.paramState.current.maxTokens = Int($0.rounded()) }
            ),
            range: 0.0...8000,
            step: 500
        )
        
        ToggleSlider(
            name: "Probability Mass (top-p)",
            use: $chat.paramState.current.useTopProbabilityMass,
            value: $chat.paramState.current.topProbabilityMass,
            range: 0.0...1.0
        )
        
        ToggleSlider(
            name: "Temperature",
            use: $chat.paramState.current.useTemperature,
            value: $chat.paramState.current.temperature,
            range: 0.0...2.0
        )
        
        ToggleSlider(
            name: "Frequency Penalty",
            use: $chat.paramState.current.useFrequencyPenalty,
            value: $chat.paramState.current.frequencyPenalty,
            range: -2.0...2.0
        )
        
        ToggleSlider(
            name: "Presence Penalty",
            use: $chat.paramState.current.usePresencePenalty,
            value: $chat.paramState.current.presencePenalty,
            range: -2.0...2.0
        )
    }
}

struct ToggleSlider: View {
    let name: String
    @Binding var use: Bool
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(name, isOn: $use)
            if use {
                Slider(
                    value: $value,
                    in: range,
                    step: step ?? Double.Stride(),
                    label: {
                        Text("\(value, format: .number)")
                    },
                    minimumValueLabel: {
                        Text("\(range.lowerBound, format: .number)")
                    },
                    maximumValueLabel: {
                        Text("\(range.upperBound, format: .number)")
                    }
                )
            }
        }
        .padding(
            [.bottom], 8.0
        )
    }
}
