//
//  MagiView.swift
//  WithAssist
//
//  Created by Ivan Lugo on 5/5/23.
//

import OpenAI
import Combine
import SwiftUI

struct MagiView: View {
    @ObservedObject var stage: MagiEntityStage
    var lolResult: String? {
        stage.magi
            .controller
            .snapshotState
            .publishedSnapshot?
            .results
            .last?
            .firstMessage?
            .content
    }
    
    var body: some View {
        mainBody
            .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    var mainBody: some View {
        VStack(alignment: .trailing) {
            loadEntityView()
            
            SaveDefinitionView(onSave: {
                print("[\(#function)] starting word save")
                stage.entity[$0.word].append($0.definition)
            })
            
            Button("Generate Observation") {
                stage.generateObservation()
            }
            
            if let result = lolResult {
                Divider()
                Text(result)
            }
            
            Divider()
            
            scrollingDefinitions()
        }
    }
    @ViewBuilder
    func scrollingDefinitions() -> some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(minimum: 48, maximum: 96)), // word
                GridItem(.flexible(minimum: 48, maximum: 400)) // definitions
            ]) {
                definitionsList()
            }
        }
        .border(Color.gray, width: 1.0)
    }
    
    @ViewBuilder
    func definitionsList() -> some View {
        ForEach(stage.entity.definitions.sortedKeys, id: \.self) { key in
            Text(key)
            
            if let definitions = stage.entity.definitions[key] {
                VStack {
                    ForEach(definitions, id: \.self) { definition in
                        Text(definition)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func loadEntityView() -> some View {
        EntityLoadView(stage: stage)
    }
}

struct NewEntry {
    let word: String
    let definition: String
}

struct SaveDefinitionView: View {
    @State var newWord: String = ""
    @State var newDefinition: String = ""
    let onSave: (NewEntry) -> Void
    
    var body: some View {
        VStack(alignment: .trailing) {
            TextField("Word", text: $newWord)
            TextField("Definition", text: $newDefinition)

            Button("Save") {
                triggerSave()
            }
        }
    }
    
    func triggerSave() {
        onSave(
            NewEntry(word: newWord, definition: newDefinition)
        )
    }
}

struct EntityLoadView: View {
    @ObservedObject var stage: MagiEntityStage
    @State var entityName: String = ""
    
    var body: some View {
        VStack(alignment: .trailing) {
            TextField("Entity Name", text: $entityName)
            .onSubmit {
                triggerLoad()
            }
            
            Button("Load") {
                triggerLoad()
            }
        }
    }
    
    func triggerLoad() {
        guard !entityName.isEmpty else {
            return
        }
        stage.loadEntity(named: entityName)
    }
}
