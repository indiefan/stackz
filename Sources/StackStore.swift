import Foundation
import Combine
import SwiftUI

class StackStore: ObservableObject {
    static let shared = StackStore()
    
    @Published var gridConfig: GridConfig {
        didSet {
            saveState()
        }
    }
    
    struct ActiveStackState: Equatable {
        let stackId: UUID
        let screenVisibleFrame: CGRect
    }
    
    @Published var activeStackState: ActiveStackState? = nil
    
    @Published var showActiveStackBorder: Bool = true {
        didSet { saveState() }
    }
    
    @Published var animateActiveStackBorder: Bool = true {
        didSet { saveState() }
    }
    
    @Published var autoSortOnDisplayChange: Bool = false {
        didSet { saveState() }
    }
    
    @Published var autoSortOnWake: Bool = false {
        didSet { saveState() }
    }
    
    @Published var stacks: [UserStack] = [] {
        didSet {
            saveState()
        }
    }
    
    private init() {
        SZLog("StackStore initialized")
        let config = AppConfigManager.shared.loadConfig()
        self.gridConfig = config.gridConfig
        self.stacks = config.stacks
        self.showActiveStackBorder = config.showActiveStackBorder ?? true
        self.animateActiveStackBorder = config.animateActiveStackBorder ?? true
        self.autoSortOnDisplayChange = config.autoSortOnDisplayChange ?? false
        self.autoSortOnWake = config.autoSortOnWake ?? false
    }
    
    func addStack(_ stack: UserStack) {
        stacks.append(stack)
    }
    
    func updateStack(_ updatedStack: UserStack) {
        if let index = stacks.firstIndex(where: { $0.id == updatedStack.id }) {
            stacks[index] = updatedStack
        }
    }
    
    func deleteStack(_ stack: UserStack) {
        let descendantIds = descendants(of: stack).map { $0.id }
        let idsToDelete = Set([stack.id] + descendantIds)
        
        stacks.removeAll { idsToDelete.contains($0.id) }
        
        // Ensure HotkeyStore removes shortcuts for all deleted stacks
        for id in idsToDelete {
            let sendKey = "send_\(id.uuidString)"
            let swapKey = "swap_\(id.uuidString)"
            let selectKey = "selectFocus_\(id.uuidString)"
            let spinKey = "spin_\(id.uuidString)"
            HotkeyStore.shared.unregister(id: sendKey)
            HotkeyStore.shared.unregister(id: swapKey)
            HotkeyStore.shared.unregister(id: selectKey)
            HotkeyStore.shared.unregister(id: spinKey)
        }
    }
    
    // MARK: - Tree Hierarchy Helpers
    
    func parent(of stack: UserStack) -> UserStack? {
        guard let parentId = stack.parentId else { return nil }
        return stacks.first(where: { $0.id == parentId })
    }
    
    func children(of stack: UserStack) -> [UserStack] {
        return stacks.filter { $0.parentId == stack.id }
    }
    
    func descendants(of stack: UserStack) -> [UserStack] {
        var result: [UserStack] = []
        let directChildren = children(of: stack)
        result.append(contentsOf: directChildren)
        for child in directChildren {
            result.append(contentsOf: descendants(of: child))
        }
        return result
    }
    
    func path(from ancestor: UserStack, to descendant: UserStack) -> [UserStack]? {
        var current = descendant
        var currPath = [current]
        
        while current.id != ancestor.id {
            guard let parent = self.parent(of: current) else {
                return nil // ancestor is not an ancestor of descendant
            }
            current = parent
            currPath.append(current)
        }
        
        return currPath.reversed() // Returns [ancestor, ..., descendant]
    }
    
    func resetAll() {
        stacks.removeAll()
        HotkeyStore.shared.resetAll()
    }
    
    func saveState() {
        let currentConfig = AppConfigManager.shared.loadConfig()
        AppConfigManager.shared.saveConfig(
            gridConfig: gridConfig, 
            stacks: stacks, 
            shortcuts: currentConfig.shortcuts,
            showBorder: showActiveStackBorder,
            animateBorder: animateActiveStackBorder,
            autoSort: autoSortOnDisplayChange,
            autoSortOnWake: autoSortOnWake
        )
    }
}
