//
//  Tokens.swift
//  WithAssist
//
//  Created by Ivan Lugo on 4/3/23.
//

import Foundation

extension String {
    var approximateTokens: Int {
        Int(Double(count) / 4.1)
    }
}
