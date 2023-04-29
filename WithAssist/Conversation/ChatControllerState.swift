//
//  ChatControllerState.swift
//  WithAssist
//
//  Created by Ivan Lugo on 3/30/23.
//

import Foundation
import OpenAI

import Combine
import SwiftUI

extension ChatController {
    class SnapshotState: ObservableObject, GlobalStoreReader {
        @Published var publishedSnapshot: Snapshot?
        @Published var currentIndex: Int = 0
        @Published var allSnapshots: AllSnapshots = AllSnapshots() {
            willSet {
                print("[all snapshots set via field accessor]")
            }
        }
        
        private var manualSaves = PassthroughSubject<AllSnapshots, Never>()
        
        private(set) var bag = Set<AnyCancellable>()
        
        init() {
            setupAutosave()
        }
        
        private static let saveQueue = DispatchQueue(
            label: "ChatAutosaveQueue", qos: .userInitiated
        )
        
        func setList(_ list: [Snapshot], isPreload: Bool) {
            allSnapshots.isSaved = isPreload
            allSnapshots.list = list
        }
        
        func setupAutosave() {
            $currentIndex
                .compactMap { self.allSnapshots[$0] }
                .sink { self.publishedSnapshot = $0 }
                .store(in: &bag)
            
            $allSnapshots
                .merge(with: manualSaves)
//                .handleEvents(receiveOutput: { _ in
//                    print("[chat state] Testing should save...")
//                })
                .filter { !$0.isSaved && !$0.list.isEmpty }
//                .handleEvents(receiveOutput: { _ in
//                    print("[chat state] Save debouncing")
//                })
                .debounce(for: 1, scheduler: Self.saveQueue)
//                .handleEvents(receiveOutput: { _ in
//                    print("[chat state] Testing duplicate...")
//                })
                .removeDuplicates()
                .map { snapshot -> AllSnapshots in
                    print("[chat state] Starting save")
                    var snapshotToSave = snapshot
                    snapshotToSave.isSaved = true
                    self.onSaveSnapshots(snapshotToSave)
                    return snapshotToSave
                }
                .receive(on: DispatchQueue.main)
                .sink {
                    print("[chat state] Setting modified state")
                    self.allSnapshots = $0
                }.store(in: &bag)
        }
        
        func load() {
            do {
                print("[load sink] starting load")
                let loaded = try snapshotStorage.load(
                    AllSnapshots.self,
                    from: .defaultSnapshot
                )
                
                self.allSnapshots = loaded
            } catch let error as CocoaError where error.isFileError {
                print("[load error] File does not exist. Creating default snapshot.", error)
                let (_, index) = allSnapshots.createNewSnapshot()
                currentIndex = index
            } catch {
                print("[load error]", error)
            }
        }
        
        func saveAll() {
            manualSaves.send(allSnapshots)
        }
        
        private func onSaveSnapshots(_ all: AllSnapshots) {
            do {
                print("[save sink] starting save to disk")
                try snapshotStorage.save(all, to: .defaultSnapshot)
            } catch {
                print("[save error]", error)
            }
        }
        
        public func usingCurrent(_ receiver: (Snapshot) -> Void) {
            guard let usingCurrent = publishedSnapshot else {
                print("[state update] no current snapshot to update")
                return
            }
            
            receiver(usingCurrent)
        }
        
        public func usingCurrent(_ receiver: (Snapshot) async -> Void) async {
            guard let usingCurrent = publishedSnapshot else {
                print("[state update] no current snapshot to update")
                return
            }
            
            await receiver(usingCurrent)
        }

        public func updateCurrent(_ receiver: (inout Snapshot) async -> Void) async {
            guard var updatedSnapshot = publishedSnapshot else {
                print("[state update] no current snapshot to update")
                return
            }

            await receiver(&updatedSnapshot)
            await MainActor.run { [updatedSnapshot] in
                allSnapshots.storeChanges(to: updatedSnapshot)
                publishedSnapshot = updatedSnapshot
            }
        }
        
        public func update(_ receiver: (ChatController.SnapshotState)-> Void) async {
            await MainActor.run {
                receiver(self)
            }
        }
        
        func startNewConversation() {
            let (_, index) = allSnapshots.createNewSnapshot()
            currentIndex = index
        }
    }
    
    class ParamState: ObservableObject {
        @Published var current: ChatRequest
        
        init(
            _ chatParams: ChatRequest = ChatRequest()
        ) {
            self.current = chatParams
        }
    }
}
