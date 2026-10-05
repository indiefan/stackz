import Foundation
import Cocoa
import Carbon

class HotkeyStore: ObservableObject {
    static let shared = HotkeyStore()
    
    @Published var shortcuts: [String: Shortcut] = [:] {
        didSet {
            saveShortcuts()
            registerGlobalMonitors()
        }
    }
    private var hotKeyRefs: [EventHotKeyRef?] = []
    
    private init() {
        SZLog("HotkeyStore initialized")
        loadShortcuts()
        setupCarbonEventHandler()
        registerGlobalMonitors()
    }
    
    func register(shortcut: Shortcut, id: String) {
        shortcuts[id] = shortcut
    }
    
    func resetAll() {
        shortcuts.removeAll()
    }
    
    func unregister(id: String) {
        shortcuts.removeValue(forKey: id)
    }
    
    private func saveShortcuts() {
        let currentConfig = AppConfigManager.shared.loadConfig()
        AppConfigManager.shared.saveConfig(
            gridConfig: currentConfig.gridConfig, 
            stacks: currentConfig.stacks, 
            shortcuts: shortcuts,
            showBorder: currentConfig.showActiveStackBorder ?? true,
            animateBorder: currentConfig.animateActiveStackBorder ?? true,
            autoSort: currentConfig.autoSortOnDisplayChange ?? false,
            autoSortOnWake: currentConfig.autoSortOnWake ?? false
        )
    }
    
    func loadShortcuts() {
        let config = AppConfigManager.shared.loadConfig()
        let decoded = config.shortcuts
        
        // Filter out legacy non-UUID keys to free up system shortcuts
        var validShortcuts: [String: Shortcut] = [:]
        for (key, shortcut) in decoded {
            let parts = key.split(separator: "_")
            if parts.count == 2, UUID(uuidString: String(parts[1])) != nil {
                validShortcuts[key] = shortcut
            } else if parts.count == 1, ActionType(rawValue: String(parts[0])) != nil {
                validShortcuts[key] = shortcut
            }
        }
        shortcuts = validShortcuts
    }
    
    private func unregisterAll() {
        for ref in hotKeyRefs {
            if let ref = ref {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeyRefs.removeAll()
        carbonIdMap.removeAll()
    }
    
    private func registerGlobalMonitors() {
        unregisterAll()
        SZLog("Registering Carbon event monitors. Active shortcuts: \(shortcuts.count)")
        
        var idCounter: UInt32 = 1
        for (id, shortcut) in shortcuts.sorted(by: { $0.key < $1.key }) {
            let carbonModifiers = shortcut.carbonModifiers
            
            var hotKeyId = EventHotKeyID()
            hotKeyId.signature = 0x53544B5A // "STKZ" as a four-char code
            hotKeyId.id = idCounter
            
            var hotKeyRef: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(shortcut.keyCode),
                UInt32(carbonModifiers),
                hotKeyId,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )
            
            if status == noErr {
                SZLog("Successfully registered Carbon hotkey for ID: \(id) [ExtID: \(idCounter)]")
                hotKeyRefs.append(hotKeyRef)
                
                // Keep a mapping so the callback knows which string ID triggered
                carbonIdMap[idCounter] = id
            } else {
                SZLog("Failed to register Carbon hotkey for ID: \(id). Status: \(status)")
            }
            idCounter += 1
        }
    }
    
    private var carbonIdMap: [UInt32: String] = [:]
    
    private func setupCarbonEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handler: EventHandlerUPP = { (_, eventRef, _) -> OSStatus in
            guard let event = eventRef else { return OSStatus(eventNotHandledErr) }
            
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            
            if status == noErr {
                HotkeyStore.shared.handleCarbonEvent(hotKeyId: hotKeyID.id)
                return noErr
            }
            return OSStatus(eventNotHandledErr)
        }
        
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, nil)
    }
    
    fileprivate func handleCarbonEvent(hotKeyId: UInt32) {
        SZLog("Carbon hotkey triggered with ExtID: \(hotKeyId)")
        if let stringId = carbonIdMap[hotKeyId] {
            SZLog("Matched Carbon ExtID \(hotKeyId) to string ID \(stringId)")
            handleShortcutActivated(id: stringId)
        }
    }
    
    func handleShortcutActivated(id: String) {
        SZLog("Activating shortcut: \(id)")
        let components = id.split(separator: "_", maxSplits: 1)
        
        let actionStr = String(components[0])
        guard let action = ActionType(rawValue: actionStr) else {
            SZLog("Invalid action type: \(actionStr)")
            return
        }
        
        var userInfo: [AnyHashable: Any] = ["action": action]
        if components.count == 2 {
            userInfo["stackId"] = String(components[1])
        }
        
        SZLog("Posting .shortcutTriggered notification for \(action)")
        NotificationCenter.default.post(
            name: .shortcutTriggered,
            object: nil,
            userInfo: userInfo
        )
    }
}

extension Notification.Name {
    static let shortcutTriggered = Notification.Name("StackzShortcutTriggered")
}

extension Shortcut {
    var carbonModifiers: Int {
        var carbonFlags = 0
        if modifiers.contains(.command) { carbonFlags |= cmdKey }
        if modifiers.contains(.option) { carbonFlags |= optionKey }
        if modifiers.contains(.control) { carbonFlags |= controlKey }
        if modifiers.contains(.shift) { carbonFlags |= shiftKey }
        return carbonFlags
    }
}
