//
//  SettingsView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/27/23.
//

import SwiftUI
import OpenAI

extension Model: CaseIterable {
    public static var allCases: [String] = [
        "text-davinci-003",
        "text-davinci-002",
        "text-davinci-001",
        "text-curie-001",
        "text-babbage-001",
        "text-search-babbage-doc-001",
        "text-search-babbage-query-001",
        "text-ada-001",
        "text-embedding-ada-002",
        "gpt-3.5-turbo",
        "gpt-3.5-turbo-0301",
        "gpt-4",
        "gpt-4-0314",
        "gpt-4-32k",
        "gpt-4-32k-0314",
        "whisper-1"
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
        }
        .listStyle(.sidebar)
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
