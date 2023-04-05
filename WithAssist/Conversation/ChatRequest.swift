//
//  ChatRequest.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/30/23.
//

import Foundation
import OpenAI
import Combine

struct ChatRequest: Equatable, Hashable {
    var useUser = true
    var user: String = "lugo-core-conversation-query"
    
    var useTemperature = false
    var temperature: Double = 0.7
    
    var useTopProbabilityMass = false
    var topProbabilityMass: Double = 0.7
    
    var completions: Int = 1
    var maxTokens: Int = ModelTokenLimit[.gpt4] ?? FallbackTokenLimit
    
    var usePresencePenalty = false
    var presencePenalty: Double = 0.5
    
    var useFrequencyPenalty = false
    var frequencyPenalty: Double = 0.5
    
    var useLogitBias = false
    var logitBias: [String: Int]? = nil
    
    var chatModel: Model = .gpt4
}
