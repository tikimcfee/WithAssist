//
//  Models.swift
//  WithAssist
//
//  Created on 4/5/23.
//

import Foundation
import OpenAI

extension Model: CaseIterable {
    public static var allCases: [String] = [
        Model.ada,
        Model.babbage,
        Model.curie,
        Model.gpt3_5Turbo,
        Model.gpt3_5Turbo0301,
        Model.gpt4,
        Model.gpt4_0314,
        Model.gpt4_32k,
        Model.gpt4_32k_0314,
        Model.whisper_1,
        Model.textDavinci_001,
        Model.textDavinci_002,
        Model.textDavinci_003,
        Model.textEmbeddingAda,
        Model.textSearchBabbadgeDoc,
        Model.textSearchBabbageQuery001
    ]
}

let FallbackTokenLimit = 4000
let ModelTokenLimit: [Model: Int] = [
    Model.curie: 2000,
    Model.babbage: 2000,
    Model.ada: 2000,
    Model.gpt3_5Turbo: 4000,
    Model.gpt3_5Turbo0301: 4000,
    Model.gpt4: 8000,
    Model.gpt4_0314: 8000,
    Model.gpt4_32k: 32000,
    Model.gpt4_32k_0314: 32000,
    Model.textDavinci_001: 4000,
    Model.textDavinci_002: 4000,
    Model.textDavinci_003: 4000
]
