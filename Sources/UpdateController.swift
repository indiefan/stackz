import SwiftUI
import Combine
import Sparkle

/// Owns the Sparkle updater.
///
/// Only release builds carry an update feed in their Info.plist. A build made with a
/// plain `./build.sh` has none, so it gets no updater and never touches the network.
final class UpdateController: NSObject, ObservableObject {
    static let shared = UpdateController()

    @Published private(set) var canCheckForUpdates = false

    /// True while a scheduled check has found an update the user hasn't looked at yet.
    @Published private(set) var hasPendingUpdate = false

    private var controller: SPUStandardUpdaterController?

    var updater: SPUUpdater? {
        controller?.updater
    }

    private override init() {
        super.init()

        guard Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil else {
            SZLog("UpdateController: no update feed in this build, updater disabled")
            return
        }

        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        self.controller = controller
        SZLog("UpdateController initialized")
    }

    func checkForUpdates() {
        // Stackz has no Dock icon, so bring Sparkle's window to the front ourselves
        NSApp.activate(ignoringOtherApps: true)
        controller?.checkForUpdates(nil)
    }
}

extension UpdateController: SPUStandardUserDriverDelegate {
    // Without a Dock icon, Sparkle opens scheduled update alerts behind other windows
    // instead of stealing focus. The menu bar menu points at them until one has been seen.
    var supportsGentleScheduledUpdateReminders: Bool {
        return true
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        if !state.userInitiated {
            SZLog("Scheduled check found version \(update.displayVersionString)")
            hasPendingUpdate = true
        }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        hasPendingUpdate = false
    }

    func standardUserDriverWillFinishUpdateSession() {
        hasPendingUpdate = false
    }
}

/// The updater entry in the menu bar menu. Renders nothing in builds without an updater.
struct UpdateMenuItem: View {
    @ObservedObject private var updates = UpdateController.shared

    var body: some View {
        if updates.updater != nil {
            Button(updates.hasPendingUpdate ? "Update Available…" : "Check for Updates…") {
                updates.checkForUpdates()
            }
            .disabled(!updates.canCheckForUpdates)
        }
    }
}

/// The "Updates" block in Settings → General. Renders nothing in builds without an updater.
struct UpdateSettingsSection: View {
    private let updater: SPUUpdater?

    // Sparkle keeps this setting in user defaults. Only write it back when the user flips the switch.
    @State private var automaticallyChecksForUpdates: Bool

    init() {
        let updater = UpdateController.shared.updater
        self.updater = updater
        self._automaticallyChecksForUpdates = State(initialValue: updater?.automaticallyChecksForUpdates ?? false)
    }

    var body: some View {
        if let updater = updater {
            VStack(alignment: .leading, spacing: 8) {
                Text("Updates")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)

                VStack(spacing: 0) {
                    SettingsRow(title: "Check for Updates Automatically") {
                        Toggle("", isOn: $automaticallyChecksForUpdates)
                            .toggleStyle(.switch)
                            .onChange(of: automaticallyChecksForUpdates) { newValue in
                                updater.automaticallyChecksForUpdates = newValue
                            }
                    }
                }
                .background(Color(white: 0.15))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
        }
    }
}
