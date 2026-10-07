import Foundation

struct AppConfig: Codable {
    var gridConfig: GridConfig
    var stacks: [UserStack]
    var shortcuts: [String: Shortcut]
    var showActiveStackBorder: Bool?
    var animateActiveStackBorder: Bool?
    var autoSortOnDisplayChange: Bool?
    var autoSortOnWake: Bool?
}

class AppConfigManager {
    static let shared = AppConfigManager()
    
    private let configURL: URL
    
    private init() {
        if NSClassFromString("XCTestCase") != nil {
            self.configURL = FileManager.default.temporaryDirectory.appendingPathComponent(".stackz_test.json")
        } else {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            self.configURL = homeDir.appendingPathComponent(".stackz.json")
        }
    }
    
    /// False until the first config file has been written, which happens on the first launch.
    var hasSavedConfig: Bool {
        FileManager.default.fileExists(atPath: configURL.path)
    }
    
    func loadConfig() -> AppConfig {
        guard let data = try? Data(contentsOf: configURL),
              var config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            // No user config on disk yet — load the bundled default (first launch).
            return loadBundledDefault()
        }

        // Provide defaults for new properties if they were missing in an older config file
        if config.showActiveStackBorder == nil { config.showActiveStackBorder = true }
        if config.animateActiveStackBorder == nil { config.animateActiveStackBorder = true }
        if config.autoSortOnDisplayChange == nil { config.autoSortOnDisplayChange = false }
        if config.autoSortOnWake == nil { config.autoSortOnWake = false }

        return config
    }

    /// Loads the default configuration bundled with the app (Resources/default_config.json).
    /// Used only on first launch, before the user config file has been written.
    /// "Reset All" does NOT restore this — it resets to empty stacks/shortcuts.
    private func loadBundledDefault() -> AppConfig {
        if let url = Bundle.main.url(forResource: "default_config", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           var config = try? JSONDecoder().decode(AppConfig.self, from: data) {
            if config.showActiveStackBorder == nil { config.showActiveStackBorder = true }
            if config.animateActiveStackBorder == nil { config.animateActiveStackBorder = true }
            if config.autoSortOnDisplayChange == nil { config.autoSortOnDisplayChange = false }
            if config.autoSortOnWake == nil { config.autoSortOnWake = false }
            return config
        }
        // Absolute fallback if the bundle resource is somehow missing
        return AppConfig(
            gridConfig: GridConfig(rows: 4, columns: 6),
            stacks: [],
            shortcuts: [:],
            showActiveStackBorder: true,
            animateActiveStackBorder: true,
            autoSortOnDisplayChange: false,
            autoSortOnWake: false
        )
    }
    
    func saveConfig(gridConfig: GridConfig, stacks: [UserStack], shortcuts: [String: Shortcut], showBorder: Bool, animateBorder: Bool, autoSort: Bool, autoSortOnWake: Bool) {
        let config = AppConfig(
            gridConfig: gridConfig, 
            stacks: stacks, 
            shortcuts: shortcuts,
            showActiveStackBorder: showBorder,
            animateActiveStackBorder: animateBorder,
            autoSortOnDisplayChange: autoSort,
            autoSortOnWake: autoSortOnWake
        )
        
        guard let data = try? JSONEncoder().encode(config) else {
            SZLog("Failed to encode AppConfig")
            return
        }
        
        do {
            try data.write(to: configURL, options: .atomic)
            SZLog("Successfully saved config to \(configURL.path)")
        } catch {
            SZLog("Failed to write config to \(configURL.path): \(error)")
        }
    }
}
