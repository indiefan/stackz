import Foundation
import Cocoa
import ApplicationServices

class ActiveStackManager {
    static let shared = ActiveStackManager()
    
    private var axObserver: AXObserver?
    private var currentAppPid: pid_t?
    
    private init() {
        SZLog("ActiveStackManager initialized")
        setupWorkspaceObserver()
        if let currentApp = NSWorkspace.shared.frontmostApplication {
            updateAXObserver(for: currentApp)
        }
        checkActiveStack(forceWindowCheck: true)
    }
    
    private func setupWorkspaceObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }
    
    @objc private func handleAppActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        updateAXObserver(for: app)
        checkActiveStack(forceWindowCheck: true)
    }
    
    private func updateAXObserver(for app: NSRunningApplication) {
        // Clear old observer
        if let observer = axObserver {
            CFRunLoopRemoveSource(RunLoop.current.getCFRunLoop(), AXObserverGetRunLoopSource(observer), CFRunLoopMode.defaultMode)
            axObserver = nil
        }
        
        currentAppPid = app.processIdentifier
        let pid = app.processIdentifier
        
        var observer: AXObserver?
        let result = AXObserverCreate(pid, { (observer, element, notification, refcon) in
            let activeStackManager = Unmanaged<ActiveStackManager>.fromOpaque(refcon!).takeUnretainedValue()
            activeStackManager.checkActiveStack(forceWindowCheck: true)
        }, &observer)
        
        guard result == .success, let newObserver = observer else {
            SZLog("Failed to create AXObserver for pid \(pid)")
            return
        }
        
        let appElement = AXUIElementCreateApplication(pid)
        
        let notifications: [CFString] = [
            kAXFocusedWindowChangedNotification as CFString,
            kAXWindowMovedNotification as CFString,
            kAXWindowResizedNotification as CFString
        ]
        
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        
        for notification in notifications {
            AXObserverAddNotification(newObserver, appElement, notification, refcon)
        }
        
        CFRunLoopAddSource(RunLoop.current.getCFRunLoop(), AXObserverGetRunLoopSource(newObserver), CFRunLoopMode.defaultMode)
        self.axObserver = newObserver
    }
    
    func checkActiveStack(forceWindowCheck: Bool = false) {
        DispatchQueue.main.async {
            self.calculateActiveStack()
        }
    }
    
    private func calculateActiveStack() {
        guard let frontWindowElement = AccessibilityElement.getFrontWindowElement() else {
            if StackStore.shared.activeStackState != nil {
                StackStore.shared.activeStackState = nil
            }
            return
        }
        
        let currentWindowFrame = frontWindowElement.frame
        let activeScreen = WindowManager.shared.getActiveScreen()
        let cgVisibleFrame = activeScreen.cgVisibleFrame
        let gridConfig = StackStore.shared.gridConfig
        let stacks = StackStore.shared.stacks
        
        let newActiveStackId = ActiveStackManager.determineActiveStack(
            for: currentWindowFrame,
            screenVisibleFrame: cgVisibleFrame,
            stacks: stacks,
            gridConfig: gridConfig
        )
        
        let newState: StackStore.ActiveStackState?
        if let newId = newActiveStackId {
            newState = StackStore.ActiveStackState(stackId: newId, screenVisibleFrame: cgVisibleFrame)
        } else {
            newState = nil
        }
        
        if StackStore.shared.activeStackState != newState {
            SZLog("Active stack state changed: Stack \(newActiveStackId?.uuidString ?? "nil") on screen bounds \(cgVisibleFrame)")
            StackStore.shared.activeStackState = newState
        }
    }
    
    static func determineActiveStack(for windowFrame: CGRect, screenVisibleFrame: CGRect, stacks: [UserStack], gridConfig: GridConfig) -> UUID? {
        for stack in stacks {
            let stackFrame = stack.targetFrame(in: screenVisibleFrame, config: gridConfig)
            if stackFrame.isStrictlyEqual(to: windowFrame) {
                return stack.id
            }
        }
        return nil
    }
}
