//
//  SettingsView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/27/23.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var chat: AsyncClient.Chat
    
    var body: some View {
        List {
            sliderBody()
        }
        .listStyle(.sidebar)
    }
    
    @ViewBuilder
    func sliderBody() -> some View {
        //        HStack {
        //            Toggle("Logit Bias", isOn: $chat.useLogitBias)
        //        }
        ToggleSlider(
            name: "Tokens",
            use: .constant(true),
            value: .init(
                get: { Double(chat.maxTokens) },
                set: { chat.maxTokens = Int($0) }
            ),
            range: 0.0...4095
        )
        
        ToggleSlider(
            name: "Probability Mass (top-p)",
            use: $chat.useTopProbabilityMass,
            value: $chat.topProbabilityMass,
            range: 0.0...1.0
        )
        
        ToggleSlider(
            name: "Temperature",
            use: $chat.useTemperature,
            value: $chat.temperature,
            range: 0.0...2.0
        )
        
        ToggleSlider(
            name: "Frequency Penalty",
            use: $chat.useFrequencyPenalty,
            value: $chat.frequencyPenalty,
            range: -2.0...2.0
        )
        
        ToggleSlider(
            name: "Presence Penalty",
            use: $chat.usePresencePenalty,
            value: $chat.presencePenalty,
            range: -2.0...2.0
        )
    }
}

struct ToggleSlider: View {
    let name: String
    @Binding var use: Bool
    @Binding var value: Double
    var range: ClosedRange<Double>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(name, isOn: $use)
            if use {
                Slider(
                    value: $value,
                    in: range,
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
