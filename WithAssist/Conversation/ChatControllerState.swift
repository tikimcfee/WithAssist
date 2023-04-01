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
        @Published var allSnapshots: AllSnapshots = AllSnapshots()
        @Published var currentIndex: Int? = nil
        private var manualSaves = PassthroughSubject<AllSnapshots, Never>()
        
        private(set) var bag = Set<AnyCancellable>()
        
        init() {
            allSnapshots.isSaved = true
            setupAutosave()
        }
        
        private static let saveQueue = DispatchQueue(
            label: "ChatAutosaveQueue", qos: .userInitiated
        )
        
        func setList(_ list: [Snapshot], isPreload: Bool) {
            allSnapshots.list = list
            allSnapshots.isSaved = isPreload
        }
        
        func setupAutosave() {
            $allSnapshots
                .merge(with: manualSaves)
                .handleEvents(receiveOutput: { _ in
                    print("[chat state] Save debouncing...")
                })
                .debounce(for: 1, scheduler: Self.saveQueue)
                .handleEvents(receiveOutput: { _ in
                    print("[chat state] Testing duplicate...")
                })
                .removeDuplicates()
                .filter { $0.shouldSave }
                .handleEvents(receiveOutput: {
                    print("[chat state] Starting save")
                    self.onSaveSnapshots($0)
                })
                .sink { _ in
                    print("[chat state] Setting is saved")
                    self.allSnapshots.setSaved()
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
            guard let usingCurrent = currentSnapshot else {
                print("[state update] no current snapshot to update")
                return
            }
            
            receiver(usingCurrent)
        }
        
        public func usingCurrent(_ receiver: (Snapshot) async -> Void) async {
            guard let usingCurrent = currentSnapshot else {
                print("[state update] no current snapshot to update")
                return
            }
            
            await receiver(usingCurrent)
        }
        
        public func updateCurrent(_ receiver: (inout Snapshot) -> Void) {
            guard var updatedSnapshot = currentSnapshot else {
                print("[state update] no current snapshot to update")
                return
            }
            
            receiver(&updatedSnapshot)
            saveSnapshotToList(updatedSnapshot)
        }

        public func updateCurrent(_ receiver: (inout Snapshot) async -> Void) async {
            guard var updatedSnapshot = currentSnapshot else {
                print("[state update] no current snapshot to update")
                return
            }

            await receiver(&updatedSnapshot)
            saveSnapshotToList(updatedSnapshot)
        }

        public var currentSnapshot: Snapshot? {
            get {
                guard let currentIndex,
                      allSnapshots.list.indices.contains(currentIndex)
                else {
                    return nil
                }
                return allSnapshots.list[currentIndex]
            }
        }
        
        func saveSnapshotToList(_ newValue: Snapshot?) {
            guard let index = allSnapshots.list.firstIndex(where: {
                $0.id == newValue?.id
            }) else {
                return
            }
            
            switch newValue {
            case .none:
                allSnapshots.list.remove(at: index)
                
            case .some(let value):
                allSnapshots.list[index] = value
            }
            
            allSnapshots.isSaved = false
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
