//
//  AppError.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/29/23.
//

import Foundation

enum AppError: Identifiable, Codable, Equatable, Hashable {
    case wrapped(String, UUID)
    
    var id: UUID {
        switch self {
        case .wrapped(_, let id):
            return id
        }
    }
    
    var message: String {
        switch self {
        case .wrapped(let message, _):
            return message
        }
    }
}
