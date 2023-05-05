//
//  MagiEntityStage.swift
//  WithAssist
//
//  Created by Ivan Lugo on 5/5/23.
//

import Foundation
import OpenAI

class MagiEntityStage: ObservableObject {
    @Published var magi: Magi
    @Published var entity: LanguageEntity
    
    @Published var observations: [ChatResult] = []
    
    private lazy var fileStore = FileStorageSerial()
    private var saveToken: Any?
    private var consultTask: Task<Void, Error>?
    
    init(
        magi: Magi,
        entity: LanguageEntity = .voidEntity
    ) {
        self.magi = magi
        self.entity = entity
        
        resetSaveToken()
    }
    
    func resetSaveToken() {
        self.saveToken = $entity
            .removeDuplicates()
            .dropFirst()
            .handleEvents(receiveOutput: saveEntity(_:))
            .sink(receiveValue: communicateChange(_:))
    }
    
    func communicateChange(_ entity: LanguageEntity) {
        consultTask.map {
            print("\($0) already running. oops.")
        }
        
        consultTask = Task { [entity] in
            if let modelResponse = await magi.consultModel(about: entity) {
                observations.append(modelResponse)
                print(modelResponse.firstMessage?.content ?? "<no content>")
            } else {
                print("[\(#function)] no change message")
            }
        }
    }
    
    private func file(_ entity: LanguageEntity) -> AppFile { file(entity.name) }
    private func file(_ name: String) -> AppFile { .custom("\(name)-entity-data") }
    
    func loadEntity(named name: String) {
        do {
            resetSaveToken()
            self.entity = try fileStore.load(LanguageEntity.self, from: file(name))
        } catch {
            print("[\(#function)] \(error)")
        }
    }
    
    func saveEntity(_ entity: LanguageEntity) {
        do {
            try fileStore.save(entity, to: file(entity))
        } catch {
            print("[\(#function)] \(error)")
        }
    }
}
