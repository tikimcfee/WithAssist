//
//  CodableAppStorage.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/26/23.
//

import SwiftUI

@propertyWrapper
struct CodableAppStorage<T: Codable> {
    let key: String
    let defaultValue: T
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    var wrappedValue: T {
        get { getValue() }
        set { setValue(newValue) }
    }
    
    private func getValue() -> T {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decodedValue = try? decoder.decode(T.self, from: data) else {
            return defaultValue
        }
        return decodedValue
    }
    
    private func setValue(_ value: T) {
        if let encodedValue = try? encoder.encode(value) {
            UserDefaults.standard.set(encodedValue, forKey: key)
        }
    }
}
