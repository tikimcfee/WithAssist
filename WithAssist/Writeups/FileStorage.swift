//
//  Persistence.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/26/23.
//

import Foundation
import SwiftUI

@MainActor
class CodableFileStorage<T: Codable>: ObservableObject {
    @Published var state: StorageState
    
    private let fileStorage = FileStorage()
    private let appFile: AppFile
    
    init(storageObject: T, appFile: AppFile) {
        self.appFile = appFile
        self.state = .idle(value: storageObject)
    }
    
    func load() async {
        do {
            if case .idle(let value) = state {
                state = .loading
                let object = try await fileStorage.load(T.self, from: appFile, defaultValue: value)
                state = .loaded(value: object)
            } else {
                throw FileStorageError.invalidState
            }
        } catch {
            state = .error(error)
        }
    }
    
    func save() async {
        guard case .loaded(let value) = state else { return }
        state = .saving
        do {
            try await fileStorage.save(value, to: appFile)
            state = .saved(value: value)
        } catch {
            state = .error(error)
        }
    }
    
    enum StorageState {
        case idle(value: T)
        case loading
        case loaded(value: T)
        case saving
        case saved(value: T)
        case error(Error)
        
        var maybeValue: T? {
            switch self {
            case .idle(let value):
                return value
                
            case .loading:
                return nil
                
            case .loaded(let value):
                return value
                
            case .saving:
                return nil
                
            case .saved(let value):
                return value
                
            case .error:
                return nil
            }
        }
    }
}

enum FileStorageError: Error {
    case invalidState
}

class FileStorage {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    func save<T: Codable>(_ object: T, to file: AppFile) async throws {
        let url = try await getURL(for: file)
        let data = try encoder.encode(object)
        try data.write(to: url, options: .atomicWrite)
    }
    
    func load<T: Codable>(_ type: T.Type, from file: AppFile, defaultValue: T) async throws -> T {
        let url = try await getURL(for: file)
        if !FileManager.default.fileExists(atPath: url.path) {
            // Create the file with the default value if it doesn't exist
            try await save(defaultValue, to: file)
        }
        let data = try Data(contentsOf: url)
        let decodedObject = try decoder.decode(T.self, from: data)
        return decodedObject
    }
    
    private func getURL(for file: AppFile) async throws -> URL {
        let url = try FileManager.default.url(for: .documentDirectory,
                                              in: .userDomainMask,
                                              appropriateFor: nil,
                                              create: true)
        return url.appendingPathComponent(file.fileName)
    }
}


class FileStorageSerial {
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    func save<T: Codable>(_ object: T, to file: AppFile) throws {
        let url = try getURL(for: file)
        let data = try encoder.encode(object)
        try data.write(to: url, options: .atomicWrite)
    }
    
    func load<T: Codable>(_ type: T.Type, from file: AppFile) throws -> T {
        let url = try getURL(for: file)
        let data = try Data(contentsOf: url)
        let decodedObject = try decoder.decode(T.self, from: data)
        return decodedObject
    }
    
    private func getURL(for file: AppFile) throws -> URL {
        let url = try fileManager.url(for: .documentDirectory,
                                      in: .userDomainMask,
                                      appropriateFor: nil,
                                      create: true)
        return url.appendingPathComponent(file.fileName)
    }
}

enum AppFile {
    case defaultSnapshot
    case custom(String)
    
    var fileName: String {
        switch self {
        case .defaultSnapshot:
            return "defaultSnapshot.json"
            
        case .custom(let customFileName):
            return customFileName
        }
    }
}
