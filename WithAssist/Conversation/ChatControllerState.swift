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
    actor SnapshotState: ObservableObject, GlobalStoreReader {
        @MainActor @Published var allSnapshots: AllSnapshots = AllSnapshots()
        @MainActor @Published var currentIndex: Int? = nil
        private var manualSaves = PassthroughSubject<AllSnapshots, Never>()
        
        private(set) var bag = Set<AnyCancellable>()

        @MainActor
        init(
            _ allSnapshots: AllSnapshots,
            _ currentIndex: Int?
        ) async {
            self.currentIndex = currentIndex
            self.allSnapshots.list.append(
                contentsOf: allSnapshots.list
            )
            
            await setupAutosave()
        }
        
        init() {
            
        }
        
        private static let saveQueue = DispatchQueue(
            label: "ChatAutosaveQueue", qos: .userInitiated
        )
        
        @MainActor
        func setList(_ list: [Snapshot]) async {
            allSnapshots.list = list
        }
        
        func setupAutosave() {
            $allSnapshots
                .merge(with: manualSaves)
                .debounce(for: 1, scheduler: Self.saveQueue)
                .removeDuplicates()
                .sink {
                    self.onSaveSnapshots($0)
                }.store(in: &bag)
        }
        
        func load() async {
            do {
                print("[load sink] starting load")
                let loaded = try snapshotStorage.load(
                    AllSnapshots.self,
                    from: .defaultSnapshot
                )
                
                await MainActor.run {
                    self.allSnapshots = loaded
                }
            } catch {
                print("[load error]", error)
            }
        }
        
        func saveAll() async {
            await MainActor.run { [allSnapshots, manualSaves] in
                manualSaves.send(allSnapshots)
            }
        }
        
        private func onSaveSnapshots(_ all: AllSnapshots) {
            do {
                print("[save sink] starting save")
                try snapshotStorage.save(all, to: .defaultSnapshot)
            } catch {
                print("[save error]", error)
            }
        }
        
        @MainActor
        public func usingCurrent(_ receiver: (Snapshot) async -> Void) async {
            guard let usingCurrent = currentSnapshot else {
                print("[state update] no current snapshot to update")
                return
            }
            
            await receiver(usingCurrent)
        }
        
        @MainActor
        public func updateCurrent(_ receiver: (inout Snapshot) -> Void) {
            guard var updatedSnapshot = currentSnapshot else {
                print("[state update] no current snapshot to update")
                return
            }
            
            receiver(&updatedSnapshot)
            currentSnapshot = updatedSnapshot
        }
        
        @MainActor
        public func updateCurrent(_ receiver: (inout Snapshot) async -> Void) async {
            guard var updatedSnapshot = currentSnapshot else {
                print("[state update] no current snapshot to update")
                return
            }
            
            await receiver(&updatedSnapshot)
            currentSnapshot = updatedSnapshot
        }
        
        @MainActor
        public var currentSnapshot: Snapshot? {
            get {
                guard let currentIndex,
                      allSnapshots.list.indices.contains(currentIndex)
                else {
                    return nil
                }
                
                return allSnapshots.list[currentIndex]
            }
            set {
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
                
                currentIndex = index
            }
        }
        
        @MainActor
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
