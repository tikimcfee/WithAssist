//
//  AppError.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/29/23.
//

import Foundation

enum AppError: Error, Identifiable, Codable, Equatable, Hashable {
    case wrapped(String, UUID = UUID())
    case custom(String, UUID = UUID())
    
    var id: UUID {
        switch self {
        case .wrapped(_, let id),
            .custom(_, let id):
            
            return id
        }
    }
    
    var message: String {
        switch self {
        case .wrapped(let message, _),
            .custom(let message, _):
            
            return message
        }
    }
}
