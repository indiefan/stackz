import SwiftUI

@main
struct StackzApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Stackz", systemImage: "squareshape.split.2x2") {
            Button("Settings") {
                appState.openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            UpdateMenuItem()

            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}

class AppState: ObservableObject {
    private var settingsWindow: NSWindow?
    private var windowDelegate: WindowDelegate?
    
    init() {
        SZLog("AppState initialized")
        checkAccessibilityPermissions()
        _ = WindowManager.shared
        _ = HotkeyStore.shared
        _ = ActiveStackManager.shared
        _ = ActiveStackOverlayManager.shared
        _ = UpdateController.shared

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.openSettings()
        }
    }
    
    func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView()
            let hostingController = NSHostingController(rootView: view)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 550),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.contentView = hostingController.view
            window.setContentSize(NSSize(width: 700, height: 550))
            window.center()
            window.title = "Stackz Settings"
            window.isReleasedWhenClosed = false
            
            self.windowDelegate = WindowDelegate(onClose: { [weak self] in
                self?.settingsWindow = nil
            })
            window.delegate = self.windowDelegate
            
            settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func checkAccessibilityPermissions() {
        let isTrusted = AXIsProcessTrusted()
        SZLog("Accessibility trusted: \(isTrusted)")
        
        if !isTrusted {
            SZLog("Accessibility permissions are required. Prompting user...")
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
        }
    }
}

class WindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
