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
    @State var lastObservation: String?
    
    var body: some View {
        mainBody
            .frame(maxWidth: .infinity)
            .padding()
            .onReceive(
                stage.magi.controller.snapshotState.$publishedSnapshot
            ) { snapshot in
                self.lastObservation = snapshot?
                    .results.last?.firstMessage?.content
            }
    }
    
    @ViewBuilder
    var mainBody: some View {
        VStack(alignment: .center) {
            loadEntityView()
            
            SaveDefinitionView(onSave: {
                print("[\(#function)] starting word save")
                stage.entity[$0.word].append($0.definition)
            })
            
            VStack {
                Button("Generate Observation") {
                    stage.generateObservation()
                }.buttonStyle(.bordered)
                
                HStack {
                    Button("Export") {
                        stage.exportEntity()
                    }.buttonStyle(.bordered)
                    
                    Button("Import") {
                        stage.importEntity()
                    }.buttonStyle(.bordered)
                }
            }
            
            if let result = lastObservation {
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(result)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("result")
                    }
                    .frame(maxHeight: 320)
                    .onChange(of: lastObservation) { _ in
                        proxy.scrollTo("result", anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            scrollingDefinitions()
        }
    }
    @ViewBuilder
    func scrollingDefinitions() -> some View {
        ScrollView {
            LazyVStack {
                definitionsList()
            }
        }
        .border(Color.gray, width: 1.0)
    }
    
    @ViewBuilder
    func definitionsList() -> some View {
        ForEach(stage.entity.definitions.sortedKeys, id: \.self) { key in
            HStack (alignment: .top) {
                Text(key)
                    .layoutPriority(1)
                
                Spacer()
                
                if let definitions = stage.entity.definitions[key] {
                    VStack(alignment: .leading) {
                        ForEach(definitions, id: \.self) { definition in
                            Text(definition)
                        }
                    }
                    .layoutPriority(1)
                }
            }
            .padding()
            .frame(maxWidth: 320)
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

            HStack {
                Button("Random Word") {
                    newWord = AppState.global.wordList.randomElement() ?? ""
                }.buttonStyle(.bordered)
                
                Button("Save") {
                    triggerSave()
                }.buttonStyle(.bordered)
            }
        }
    }
    
    func setRandomWord() {
        
        newDefinition = ""
    }
    
    func triggerSave() {
        onSave(
            NewEntry(word: newWord, definition: newDefinition)
        )
        newWord = ""
        newDefinition = ""                                                                              
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
