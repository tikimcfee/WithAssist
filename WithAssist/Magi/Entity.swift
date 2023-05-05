//
//  Entity.swift
//  WithAssist
//
//  Created by Ivan Lugo on 5/5/23.
//

import Foundation

typealias EntityMap = [String: [String]]

struct LanguageEntity: Codable, Equatable, Hashable {
    var name: String
    var definitions: EntityMap = EntityMap()
    
    static let voidEntity = LanguageEntity(name: "default_void_entity")
    
//    subscript (_ word: String, _ index: Int = 0) -> String? {
//        get {
//            if let list = definitions[word],
//               list.indices.contains(index) {
//                return list[index]
//            }
//            return nil
//        }
//        set {
//            var list = definitions[word, default: []]
//            if list.indices.contains(index) {
//                if let newValue {
//                    list[index] = newValue
//                } else {
//                    list.remove(at: index)
//                }
//            } else {
//                if let newValue {
//                    list.append(newValue)
//                }
//            }
//            definitions[word] = list
//        }
//    }
    
    subscript (_ word: String) -> [String] {
        get {
            return definitions[word, default: []]
        }
        set {
            definitions[word] = newValue
        }
    }
}

extension EntityMap: RawRepresentable {
    public var rawValue: String {
        do {
            let data = try JSONEncoder().encode(self)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            print(error)
            return ""
        }
    }
    
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let map = try? JSONDecoder().decode(Self.self, from: data)
        else {
            return nil
        }
        self = map
    }
    
    var sortedKeys: [String] {
        keys.sorted()
    }
}

struct EntityDelta {
    static let empty = EntityDelta()
}

struct EntityUnion {
    static let empty = EntityUnion()
}
