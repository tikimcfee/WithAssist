//
//  SettingsView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/27/23.
//

import SwiftUI
import OpenAI
import Foundation

extension Model: CaseIterable {
    public static var allCases: [String] = [
        .textDavinci_003,
        .textDavinci_002,
        .textDavinci_001,
        .curie,
        .babbage,
        .textSearchBabbadgeDoc,
        .textSearchBabbageQuery001,
        .ada,
        .textEmbeddingAda,
        .gpt3_5Turbo,
        .gpt3_5Turbo0301,
        .gpt4,
        .gpt4_0314,
        .gpt4_32k,
        .gpt4_32k_0314,
        .whisper_1
    ]
}

struct SettingsView: View {
    @ObservedObject var controller: ChatController
    
    var body: some View {
        List {
            Button("Update token") {
                controller.setNeedsNewToken()
            }
            userField()
            modelPickerView()
            sliderBody()
            pathsView()
        }
        .listStyle(.sidebar)
    }
    
    @ViewBuilder
    func pathsView() -> some View {
        Button("Copy conversation path to clipboard") {
            if let url = try? FileStorageSerial.shared.url(for: .defaultSnapshot) {
                NSPasteboard.general.setString(url.path(percentEncoded: false), forType: .string)
            }
        }
    }
    
    @ViewBuilder
    func userField() -> some View {
        TextField("User", text: $controller.paramState.current.user)
            .underline()
    }
    
    @ViewBuilder
    func modelPickerView() -> some View {
        Picker("GPT Model", selection: $controller.paramState.current.chatModel) {
            ForEach(Model.allCases, id: \.hashValue) { model in
                Text(model)
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
                get: { Double(controller.paramState.current.maxTokens) },
                set: { controller.paramState.current.maxTokens = Int($0.rounded()) }
            ),
            range: 0.0...8000,
            step: 500
        )
        
        ToggleSlider(
            name: "Probability Mass (top-p)",
            use: $controller.paramState.current.useTopProbabilityMass,
            value: $controller.paramState.current.topProbabilityMass,
            range: 0.0...1.0
        )
        
        ToggleSlider(
            name: "Temperature",
            use: $controller.paramState.current.useTemperature,
            value: $controller.paramState.current.temperature,
            range: 0.0...2.0
        )
        
        ToggleSlider(
            name: "Frequency Penalty",
            use: $controller.paramState.current.useFrequencyPenalty,
            value: $controller.paramState.current.frequencyPenalty,
            range: -2.0...2.0
        )
        
        ToggleSlider(
            name: "Presence Penalty",
            use: $controller.paramState.current.usePresencePenalty,
            value: $controller.paramState.current.presencePenalty,
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
                DoubleInputView(value: $value, range: range)
            }
        }
        
    }
}

struct DoubleInputView: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    @State private var textValue: String
    
    init(value: Binding<Double>, range: ClosedRange<Double>) {
        self._value = value
        self.range = range
        self._textValue = State(initialValue: String(format: "%.2f", value.wrappedValue))
    }
    
    var body: some View {
        inputField
            .padding(.top, 4)
            .textFieldStyle(.roundedBorder)
    }
    
    var inputField: some View {
#if os(macOS)
        TextField("Enter value", text: $textValue)
            .multilineTextAlignment(.trailing)
            .onSubmit {
                updateValue()
            }
#else
        TextField("Enter value", text: $textValue)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .onSubmit {
                updateValue()
            }
#endif
    }
    
    private func updateValue() {
        if let newValue = Double(textValue) {
            value = min(max(newValue, range.lowerBound), range.upperBound)
            textValue = String(format: "%.2f", value)
        } else {
            textValue = ""
            textValue = String(format: "%.2f", value)
        }
    }
}
