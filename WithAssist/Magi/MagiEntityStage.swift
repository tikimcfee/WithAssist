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
    }
    
    func exportEntity() {
        let file = file(entity.name)
        if let url = try? fileStore.getURL(for: file) {
            print("Entity at: \(url)")
        }
    }
    
    func importEntity() {
        
    }
    
    func resetSaveToken() {
        self.saveToken = $entity
            .filter {
                !$0.definitions.isEmpty
            }
            .removeDuplicates()
            .sink(receiveValue: saveEntity(_:))
    }
    
    func generateObservation() {
        consultTask.map {
            print("\($0) already running. oops.")
        }
        
        print("[\(#function)] starting change")
        consultTask = Task { [entity] in
            if let modelResponse = await magi.consultModel(about: entity) {
                await MainActor.run {
                    observations.append(modelResponse)
                }
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
            self.entity = try fileStore.load(
                LanguageEntity.self,
                from: file(name),
                onMissingFile: LanguageEntity(name: name)
            )
            resetSaveToken()
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
