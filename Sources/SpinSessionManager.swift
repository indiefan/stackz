import Foundation
import Cocoa

class SpinSessionManager {
    static let shared = SpinSessionManager()
    
    private var overlayController = SpinOverlayWindowController()
    private var eventMonitor: Any?
    
    private var isActive = false
    private var currentWindows: [WindowSummary] = []
    private var currentIndex = 0
    private var requiredModifiers: NSEvent.ModifierFlags = []
    
    private init() {}
    
    func spin(stack: UserStack, modifiers: NSEvent.ModifierFlags) {
        let screen = WindowManager.shared.getActiveScreen()
        let cgVisibleFrame = screen.cgVisibleFrame
        let targetFrame = stack.targetFrame(in: cgVisibleFrame, config: StackStore.shared.gridConfig)
        
        let windows = ZOrderLookup.findAllWindows(in: targetFrame)
        spin(windows: windows, screen: screen, modifiers: modifiers)
    }
    
    func spin(windows: [WindowSummary], screen: NSScreen, modifiers: NSEvent.ModifierFlags) {
        if isActive {
            // Advance the index
            guard !currentWindows.isEmpty else { return }
            currentIndex = (currentIndex + 1) % currentWindows.count
            
            let targetWindowId = currentWindows[currentIndex].windowId
            if let targetWindowElement = AccessibilityElement.getWindowElement(targetWindowId) {
                targetWindowElement.bringToFront()
            }
            
            overlayController.show(windows: currentWindows, selectedIndex: currentIndex, screen: screen)
        } else {
            guard !windows.isEmpty else {
                SZLog("No windows provided to spin.")
                return
            }
            
            isActive = true
            currentWindows = windows
            requiredModifiers = modifiers.intersection([.command, .option, .control, .shift])
            if requiredModifiers.isEmpty {
                // If there were no modifiers pressed (e.g., F-key), just commit immediately
                let activeWindowId = AccessibilityElement.getFrontWindowElement()?.windowId
                var nextIndex = 0
                if let activeId = activeWindowId,
                   let idx = windows.firstIndex(where: { $0.windowId == activeId }) {
                    nextIndex = (idx + 1) % windows.count
                }
                let targetId = windows[nextIndex].windowId
                AccessibilityElement.getWindowElement(targetId)?.bringToFront()
                isActive = false
                currentWindows = []
                return
            }
            
            // Determine active index based on currently focused window
            let activeWindowId = AccessibilityElement.getFrontWindowElement()?.windowId
            currentIndex = 0
            if let activeId = activeWindowId,
               let idx = windows.firstIndex(where: { $0.windowId == activeId }) {
                currentIndex = (idx + 1) % windows.count
            }
            
            let targetWindowId = currentWindows[currentIndex].windowId
            if let targetWindowElement = AccessibilityElement.getWindowElement(targetWindowId) {
                targetWindowElement.bringToFront()
            }
            
            overlayController.show(windows: currentWindows, selectedIndex: currentIndex, screen: screen)
            startTrackingModifiers()
            
            // Check immediately if the modifiers were already released
            let currentGlobalFlags = NSEvent.modifierFlags.intersection([.command, .option, .control, .shift])
            if !currentGlobalFlags.isSuperset(of: requiredModifiers) {
                // Modifiers were released instantly, process a quick-spin.
                commitSpin()
            }
        }
    }
    
    private func startTrackingModifiers() {
        if eventMonitor != nil {
            NSEvent.removeMonitor(eventMonitor!)
        }
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
    }
    
    private func handleFlagsChanged(_ event: NSEvent) {
        guard isActive else { return }
        
        let currentFlags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        
        // If the user released *any* of the required modifiers, commit the action
        if !currentFlags.isSuperset(of: requiredModifiers) {
            commitSpin()
        }
    }
    
    private func commitSpin() {
        guard isActive, !currentWindows.isEmpty else { return }
        
        let targetWindowId = currentWindows[currentIndex].windowId
        if let targetWindowElement = AccessibilityElement.getWindowElement(targetWindowId) {
            targetWindowElement.bringToFront()
        }
        
        endSession()
    }
    
    func endSession() {
        isActive = false
        currentWindows = []
        overlayController.hide()
        
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
