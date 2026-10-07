import SwiftUI
import ServiceManagement

/// Registers Stackz as a login item through SMAppService, so macOS starts it at login.
final class LoginItem: ObservableObject {
    static let shared = LoginItem()
    
    @Published private(set) var isEnabled = false
    
    /// macOS can hold a new login item back until the user approves it in System Settings.
    @Published private(set) var needsApproval = false
    
    private init() {
        refresh()
    }
    
    /// Re-reads the state, which the user may also have changed in System Settings.
    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        needsApproval = status == .requiresApproval
    }
    
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            SZLog("Launch at login \(enabled ? "enabled" : "disabled")")
        } catch {
            SZLog("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
        refresh()
    }
}

/// The "Startup" block in Settings → General.
struct LaunchAtLoginSection: View {
    @ObservedObject private var loginItem = LoginItem.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Startup")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                SettingsRow(title: "Launch at Login") {
                    Toggle("", isOn: Binding(
                        get: { loginItem.isEnabled || loginItem.needsApproval },
                        set: { loginItem.setEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                }
                
                if loginItem.needsApproval {
                    Divider().background(Color.white.opacity(0.1))
                    SettingsRow(title: "macOS is waiting for you to allow Stackz in Login Items.") {
                        Button("Open Login Items") {
                            SMAppService.openSystemSettingsLoginItems()
                        }
                    }
                }
            }
            .background(Color(white: 0.15))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .onAppear {
            loginItem.refresh()
        }
    }
}
