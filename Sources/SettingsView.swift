import SwiftUI
import Carbon
import Cocoa

struct SettingsView: View {
    enum Tab: Hashable {
        case general
        case stacks
    }
    
    @State private var selectedTab: Tab = .stacks
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 4) {
                Spacer().frame(height: 48) // Traffic light clearance
                
                SidebarButton(title: "General", icon: "gearshape", isSelected: selectedTab == .general) { selectedTab = .general }
                SidebarButton(title: "Stacks", icon: "rectangle.stack", isSelected: selectedTab == .stacks) { selectedTab = .stacks }
                
                Spacer()
            }
            .frame(width: 85)
            .background(Color(white: 0.16))
            
            // Optional separator line
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .frame(width: 1)
            
            // Detail / Main Content Area
            VStack(spacing: 0) {
                // Custom Header
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LinearGradient(colors: [.cyan, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 28, height: 28)
                        Text("S")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text("Stackz Settings")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.bottom, 12)
                .padding(.leading, 16)
                .background(Color(white: 0.12)) // Ensure same color as content
                
                Divider().background(Color.white.opacity(0.05))
                
                // Active Tab Content
                Group {
                    switch selectedTab {
                    case .general:
                        GeneralSettingsTab()
                    case .stacks:
                        StacksSettingsTab()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(white: 0.12))
            }
        }
        .ignoresSafeArea(.all)
        .frame(width: 700, height: 550)
        .preferredColorScheme(.dark)
    }
}

struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .light))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? Color.white.opacity(0.12) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct GeneralSettingsTab: View {
    @StateObject private var stackStore = StackStore.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Global Grid Configuration Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Global Grid Configuration")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
                        SettingsRow(title: "Columns:") {
                            HStack(spacing: 12) {
                                Text("\(stackStore.gridConfig.columns)")
                                    .frame(width: 24, alignment: .trailing)
                                Stepper("", value: $stackStore.gridConfig.columns, in: 2...24)
                            }
                        }
                        Divider().background(Color.white.opacity(0.1))
                        
                        SettingsRow(title: "Rows:") {
                            HStack(spacing: 12) {
                                Text("\(stackStore.gridConfig.rows)")
                                    .frame(width: 24, alignment: .trailing)
                                Stepper("", value: $stackStore.gridConfig.rows, in: 2...24)
                            }
                        }
                        Divider().background(Color.white.opacity(0.1))
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Grid Preview:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            GridPreviewView(config: stackStore.gridConfig)
                                .frame(width: 240, height: 160) // 3:2 Aspect Ratio (Matches Editor)
                                .background(Color(white: 0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(white: 0.3), lineWidth: 1)
                                )
                                .padding(.top, 4)
                        }
                        .padding(16)
                    }
                    .background(Color(white: 0.15))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                
                // Global Shortcuts Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Global Shortcuts")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
                        SettingsRow(title: "Send Window to Next Monitor:") {
                            ShortcutRecorder(actionType: .sendToNextMonitor, stackId: nil)
                                .frame(width: 150)
                        }
                        Divider().background(Color.white.opacity(0.1))
                        
                        SettingsRow(title: "Swap Window with Next Monitor:") {
                            ShortcutRecorder(actionType: .swapToNextMonitor, stackId: nil)
                                .frame(width: 150)
                        }
                        Divider().background(Color.white.opacity(0.1))
                        
                        SettingsRow(title: "Select Next Monitor:") {
                            ShortcutRecorder(actionType: .selectNextMonitor, stackId: nil)
                                .frame(width: 150)
                        }
                        Divider().background(Color.white.opacity(0.1))
                        
                        SettingsRow(title: "Global Spin:") {
                            ShortcutRecorder(actionType: .globalSpin, stackId: nil)
                                .frame(width: 150)
                        }
                        Divider().background(Color.white.opacity(0.1))
                        
                        SettingsRow(title: "Sort into Stacks:") {
                            ShortcutRecorder(actionType: .sortIntoStacks, stackId: nil)
                                .frame(width: 150)
                        }
                    }
                    .background(Color(white: 0.15))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                
                // Active Stack Border Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Stack Border")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
                        SettingsRow(title: "Show Border on Stack Change") {
                            Toggle("", isOn: $stackStore.showActiveStackBorder)
                                .toggleStyle(.switch)
                        }
                        Divider().background(Color.white.opacity(0.1))
                        
                        SettingsRow(title: "Animate Border Glowing") {
                            Toggle("", isOn: $stackStore.animateActiveStackBorder)
                                .toggleStyle(.switch)
                                .disabled(!stackStore.showActiveStackBorder)
                        }
                        .opacity(stackStore.showActiveStackBorder ? 1.0 : 0.5)
                    }
                    .background(Color(white: 0.15))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                
                // Window Management Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Window Management")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 0) {
                        SettingsRow(title: "Auto-Sort on Monitor Change") {
                            Toggle("", isOn: $stackStore.autoSortOnDisplayChange)
                                .toggleStyle(.switch)
                        }
                        Divider().background(Color.white.opacity(0.1))
                        
                        SettingsRow(title: "Auto-Sort on Login/Wake") {
                            Toggle("", isOn: $stackStore.autoSortOnWake)
                                .toggleStyle(.switch)
                        }
                    }
                    .background(Color(white: 0.15))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                

            }
            .padding(24)
            .padding(.bottom, 20)
        }
        .padding()
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct GridPreviewView: View {
    let config: GridConfig
    
    var body: some View {
        GeometryReader { geometry in
            let cols = config.columns
            let rows = config.rows
            
            ZStack(alignment: .topLeading) {
                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<cols, id: \.self) { col in
                        let cellFrame = UserStack.cellFrame(col: col, row: row, containerSize: geometry.size, config: config)
                        
                        Rectangle()
                            .fill(Color.cyan)
                            .overlay(
                                Rectangle()
                                    .stroke(Color(white: 0.1), lineWidth: 1)
                            )
                            .shadow(color: .cyan.opacity(0.6), radius: 8)
                            .frame(width: cellFrame.width, height: cellFrame.height)
                            .position(x: cellFrame.midX, y: cellFrame.midY)
                    }
                }
            }
        }
    }
}

struct StacksSettingsTab: View {
    @StateObject private var stackStore = StackStore.shared
    @State private var showingResetConfirmation = false
    
    @State private var activeSheet: ActiveSheet?
    @State private var selectedStackId: UUID?
    @State private var hoveredStackId: UUID?
    
    enum ActiveSheet: Identifiable {
        case edit(UserStack)
        case new
        case split(UserStack)
        var id: String {
            switch self {
            case .edit(let stack): return "edit_\(stack.id)"
            case .new: return "new"
            case .split(let stack): return "split_\(stack.id)"
            }
        }
    }
    
    // Tracks stacks that have been explicitly collapsed. Empty by default = all expanded.
    @State private var collapsedStackIds: Set<UUID> = []

    private var orderedStacks: [(stack: UserStack, depth: Int, hasChildren: Bool, isExpanded: Bool)] {
        var result: [(stack: UserStack, depth: Int, hasChildren: Bool, isExpanded: Bool)] = []
        let roots = stackStore.stacks.filter { $0.parentId == nil }

        func traverse(stack: UserStack, depth: Int) {
            let children = stackStore.stacks.filter { $0.parentId == stack.id }
                .sorted { $0.isMain && !$1.isMain }

            let hasC = !children.isEmpty
            let isE = !collapsedStackIds.contains(stack.id)

            result.append((stack, depth, hasC, isE))

            if isE {
                for child in children {
                    traverse(stack: child, depth: depth + 1)
                }
            }
        }

        for root in roots {
            traverse(stack: root, depth: 0)
        }
        return result
    }

    private func toggleExpansion(for stack: UserStack, isExpanded: Bool) {
        if isExpanded {
            // Currently expanded → collapse it and all its descendants
            collapsedStackIds.insert(stack.id)
            for id in stackStore.descendants(of: stack).map({ $0.id }) {
                collapsedStackIds.insert(id)
            }
        } else {
            // Currently collapsed → expand it and all its descendants
            collapsedStackIds.remove(stack.id)
            for id in stackStore.descendants(of: stack).map({ $0.id }) {
                collapsedStackIds.remove(id)
            }
        }
    }
    
    var body: some View {
        VStack {
            List(selection: $selectedStackId) {
                ForEach(orderedStacks, id: \.stack.id) { item in
                    let stack = item.stack
                    let depth = item.depth
                    
                    StackListItem(
                        stack: stack,
                        hasChildren: item.hasChildren,
                        isExpanded: item.isExpanded,
                        onToggleExpand: {
                            toggleExpansion(for: stack, isExpanded: item.isExpanded)
                        },
                        onSplit: {
                            activeSheet = .split(stack)
                        }
                    )
                        .padding(.leading, CGFloat(depth * 30))
                        .tag(stack.id)
                        .contentShape(Rectangle())
                        .onHover { isHovered in
                            if isHovered {
                                hoveredStackId = stack.id
                            } else if hoveredStackId == stack.id {
                                hoveredStackId = nil
                            }
                        }
                        .listRowBackground(
                            Group {
                                if selectedStackId == stack.id {
                                    Color.accentColor.opacity(0.8).cornerRadius(6).padding(.horizontal, 4)
                                } else if hoveredStackId == stack.id {
                                    Color.white.opacity(0.1).cornerRadius(6).padding(.horizontal, 4)
                                } else {
                                    Color.clear
                                }
                            }
                        )
                        .simultaneousGesture(TapGesture().onEnded {
                            selectedStackId = stack.id
                        })
                        .simultaneousGesture(TapGesture(count: 2).onEnded {
                            activeSheet = .edit(stack)
                        })
                }
            }
            .listStyle(PlainListStyle())
            
            HStack {
                Button("Reset All") {
                    showingResetConfirmation = true
                }
                .foregroundColor(.red)
                
                Spacer()
                
                Button("New Stack") {
                    activeSheet = .new
                }
            }
            .padding()
        }
        .alert(isPresented: $showingResetConfirmation) {
            Alert(
                title: Text("Reset All Settings?"),
                message: Text("This will permanently delete all configured stacks and free all assigned system shortcuts. This action cannot be undone."),
                primaryButton: .destructive(Text("Reset All")) {
                    StackStore.shared.resetAll()
                    selectedStackId = nil
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(item: $activeSheet) { sheet in
            let isPresented = Binding<Bool>(
                get: { activeSheet != nil },
                set: { if !$0 { activeSheet = nil } }
            )
            
            switch sheet {
            case .edit(let stack):
                StackEditorDialog(
                    stack: stack,
                    isNew: false,
                    isPresented: isPresented
                )
            case .new:
                StackEditorDialog(
                    stack: UserStack(startCol: 0, startRow: 0, endCol: 0, endRow: 0),
                    isNew: true,
                    isPresented: isPresented
                )
            case .split(let stack):
                StackSplitDialog(
                    parentStack: stack,
                    isPresented: isPresented
                )
            }
        }
    }
}

struct StackListItem: View {
    let stack: UserStack
    var hasChildren: Bool = false
    var isExpanded: Bool = false
    var onToggleExpand: (() -> Void)? = nil
    var onSplit: (() -> Void)? = nil
    
    @StateObject private var hotkeyStore = HotkeyStore.shared
    @StateObject private var stackStore = StackStore.shared
    
    var sendShortcut: String {
        return hotkeyStore.shortcuts["send_\(stack.id.uuidString)"]?.description ?? "Not set"
    }
    private var swapShortcut: String {
        let key = "swap_\(stack.id.uuidString)"
        return HotkeyStore.shared.shortcuts[key]?.description ?? "Not set"
    }

    private var selectShortcut: String {
        let key = "selectFocus_\(stack.id.uuidString)"
        return HotkeyStore.shared.shortcuts[key]?.description ?? "Not set"
    }

    private var spinShortcut: String {
        let key = "spin_\(stack.id.uuidString)"
        return HotkeyStore.shared.shortcuts[key]?.description ?? "Not set"
    }
    
    var body: some View {
        HStack(spacing: 20) {
            if hasChildren {
                Button(action: {
                    onToggleExpand?()
                }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 16, height: 16)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if stack.parentId != nil {
                     Text(stack.isMain ? "Main Substack (*)" : "Minor Substack")
                         .font(.caption)
                         .foregroundColor(stack.isMain ? .accentColor : .secondary)
                }
                HStack {
                    Text("Send:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(sendShortcut)
                        .font(.headline)
                }
                HStack {
                    Text("Swap:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(swapShortcut)
                        .font(.subheadline)
                }
                HStack {
                    Text("Select:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(selectShortcut)
                        .font(.subheadline)
                }
                HStack {
                    Text("Spin:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(spinShortcut)
                        .font(.subheadline)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 10) {
                Button("Split") {
                    onSplit?()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                StackGridThumbnailView(stack: stack, config: stackStore.gridConfig)
                    .frame(width: 48, height: 32)
            }
        }
        .padding(.vertical, 8)
    }
}

struct StackGridThumbnailView: View {
    let stack: UserStack
    let config: GridConfig
    @StateObject private var stackStore = StackStore.shared
    
    var body: some View {
        GeometryReader { geometry in
            let cols = config.columns
            let rows = config.rows
            let parentStack = stack.parentId.flatMap { id in stackStore.stacks.first { $0.id == id } }
            
            ZStack(alignment: .topLeading) {
                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<cols, id: \.self) { col in
                        let isSelected = col >= stack.startCol && col <= stack.endCol &&
                                         row >= stack.startRow && row <= stack.endRow
                        
                        let isParent = parentStack.map { p in
                            col >= p.startCol && col <= p.endCol &&
                            row >= p.startRow && row <= p.endRow
                        } ?? false
                        
                        let cellFrame = UserStack.cellFrame(col: col, row: row, containerSize: geometry.size, config: config)
                        
                        Rectangle()
                            .fill(isSelected ? Color.cyan : (isParent ? Color(white: 0.5) : Color(white: 0.2)))
                            .overlay(
                                Rectangle()
                                    .stroke(Color(white: 0.1), lineWidth: 1)
                            )
                            .shadow(color: isSelected ? .cyan.opacity(0.5) : .clear, radius: isSelected ? 4 : 0)
                            .frame(width: cellFrame.width, height: cellFrame.height)
                            .position(x: cellFrame.midX, y: cellFrame.midY)
                    }
                }
            }
        }
    }
}

struct StackEditorDialog: View {
    @State var stack: UserStack
    let isNew: Bool
    @Binding var isPresented: Bool

    // Ordered sequence of the four per-stack shortcut slots.
    private static let shortcutOrder: [ActionType] = [.send, .swap, .selectFocus, .spin]

    /// After a shortcut is set for `actionType`, start recording the next slot that is still unset.
    private func autoAdvance(after actionType: ActionType) {
        let stackIdStr = stack.id.uuidString
        guard let currentIdx = Self.shortcutOrder.firstIndex(of: actionType) else { return }
        for i in (currentIdx + 1)..<Self.shortcutOrder.count {
            let next = Self.shortcutOrder[i]
            let id = "\(next.rawValue)_\(stackIdStr)"
            if HotkeyStore.shared.shortcuts[id] == nil {
                SettingsRecorder.shared.onCurrentSet = { autoAdvance(after: next) }
                SettingsRecorder.shared.recordingId = id
                return
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(isNew ? "Create New Stack" : "Edit Stack")
                .font(.headline)

            StackGridSelectionView(stack: $stack)
                .frame(width: 300, height: 200)
                .background(Color(white: 0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(white: 0.3), lineWidth: 1)
                )
                .padding(.bottom, 10)

            VStack(alignment: .trailing, spacing: 10) {
                HStack {
                    Text("Send Shortcut:")
                    ShortcutRecorder(actionType: .send, stackId: stack.id.uuidString,
                                     onSet: { autoAdvance(after: .send) })
                        .frame(width: 150)
                }
                HStack {
                    Text("Swap Shortcut:")
                    ShortcutRecorder(actionType: .swap, stackId: stack.id.uuidString,
                                     onSet: { autoAdvance(after: .swap) })
                        .frame(width: 150)
                }
                HStack {
                    Text("Select Shortcut:")
                    ShortcutRecorder(actionType: .selectFocus, stackId: stack.id.uuidString,
                                     onSet: { autoAdvance(after: .selectFocus) })
                        .frame(width: 150)
                }
                HStack {
                    Text("Spin Shortcut:")
                    ShortcutRecorder(actionType: .spin, stackId: stack.id.uuidString,
                                     onSet: { autoAdvance(after: .spin) })
                        .frame(width: 150)
                }
            }
            .padding(16)
            .background(Color(white: 0.15))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
            )
            
            HStack {
                if !isNew {
                    Button("Delete") {
                        StackStore.shared.deleteStack(stack)
                        isPresented = false
                    }
                    .foregroundColor(.red)
                }
                
                Spacer()
                
                Button("Cancel") {
                    isPresented = false
                }
                
                Button("Save") {
                    if isNew {
                        StackStore.shared.addStack(stack)
                    } else {
                        StackStore.shared.updateStack(stack)
                    }
                    isPresented = false
                }
                .buttonStyle(BorderedProminentButtonStyle())
            }
        }
        .padding()
        .frame(width: 400)
    }
}

enum ActionType: String {
    case send
    case swap
    case selectFocus
    case spin
    case sendToNextMonitor
    case swapToNextMonitor
    case selectNextMonitor
    case globalSpin
    case sortIntoStacks
}

struct ShortcutParser {
    static func parse(event: NSEvent) -> Shortcut? {
        // Extract only the semantic modifiers we care about.
        let rawModifiers = event.modifierFlags.rawValue
        let relevantFlags = NSEvent.ModifierFlags(rawValue: rawModifiers & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue)
        
        let modifiers = relevantFlags.intersection([.command, .option, .control, .shift])
        let keyCode = Int(event.keyCode)
        
        // Allow Escape to cancel
        if keyCode == 53 /* Escape */ { return nil }
        
        // Disallow Delete/Backspace as normal shortcut bindings since they are used to unset
        if keyCode == 51 || keyCode == 117 { return nil }
        
        // Ignore if it's JUST a modifier key being pressed down
        let isModifierKey = Set([54, 55, 56, 59, 60, 61, 62]).contains(keyCode)
        
        if !isModifierKey {
            // Require Command, Control or Option. Shift alone would turn ordinary typing
            // (capital letters, symbols) into a global shortcut.
            if !modifiers.isDisjoint(with: [.command, .option, .control]) {
                return Shortcut(keyCode: keyCode, modifiers: modifiers)
            }
        }
        return nil
    }
}

class SettingsRecorder: ObservableObject {
    static let shared = SettingsRecorder()
    @Published var recordingId: String? = nil
    /// Called (then cleared) when a shortcut is successfully registered. Used for auto-advance.
    var onCurrentSet: (() -> Void)? = nil
    private var localMonitor: Any?
    private var globalMonitor: Any?

    init() {
        let handler: (NSEvent) -> NSEvent? = { [weak self] event in
            guard let self = self, let activeId = self.recordingId else { return event }

            SZLog("Recorder captured raw key event: keyCode=\(event.keyCode), modifiers=\(event.modifierFlags.rawValue)")

            if event.keyCode == 53 {
                // Escape immediately cancels
                self.onCurrentSet = nil
                self.recordingId = nil
                return nil
            }

            if event.keyCode == 51 || event.keyCode == 117 {
                // Delete unsets the currently recording shortcut (not a "set", so don't advance)
                HotkeyStore.shared.unregister(id: activeId)
                self.onCurrentSet = nil
                self.recordingId = nil
                return nil
            }

            if let shortcut = ShortcutParser.parse(event: event) {
                HotkeyStore.shared.register(shortcut: shortcut, id: activeId)
                self.recordingId = nil
                let callback = self.onCurrentSet
                self.onCurrentSet = nil
                callback?()
                return nil
            }
            return event
        }
        
        // Listen locally (when app is in focus)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: handler)
        
        // Listen globally (in case the Settings window loses focus while recording)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            _ = handler(event)
        }
    }
    
    deinit {
        if let localMonitor = localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor = globalMonitor { NSEvent.removeMonitor(globalMonitor) }
    }
}

struct ShortcutRecorder: View {
    let actionType: ActionType
    let stackId: String?
    /// Called after a shortcut is successfully set, for auto-advance in the editor.
    var onSet: (() -> Void)? = nil

    @StateObject private var hotkeyStore = HotkeyStore.shared
    @StateObject private var recorder = SettingsRecorder.shared

    var hotkeyId: String {
        if let regId = stackId {
            return "\(actionType.rawValue)_\(regId)"
        }
        return actionType.rawValue
    }

    var isRecording: Bool {
        recorder.recordingId == hotkeyId
    }

    var currentShortcut: String {
        if let shortcut = hotkeyStore.shortcuts[hotkeyId] {
            return shortcut.description
        }
        return "Not Set"
    }

    var body: some View {
        Button(action: {
            if isRecording {
                recorder.onCurrentSet = nil
                recorder.recordingId = nil
            } else {
                recorder.onCurrentSet = onSet
                recorder.recordingId = hotkeyId
            }
        }) {
            Text(isRecording ? "Press keys (Esc to cancel)..." : currentShortcut)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .background(isRecording ? Color.accentColor.opacity(0.3) : Color.clear)
        .cornerRadius(4)
    }
}

struct StackGridSelectionView: View {
    @Binding var stack: UserStack
    @StateObject private var stackStore = StackStore.shared
    
    var body: some View {
        GeometryReader { geometry in
            let cols = stackStore.gridConfig.columns
            let rows = stackStore.gridConfig.rows
            
            ZStack(alignment: .topLeading) {
                // Background grid cells
                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<cols, id: \.self) { col in
                        let isSelected = isCellSelected(col: col, row: row)
                        let cellFrame = UserStack.cellFrame(col: col, row: row, containerSize: geometry.size, config: stackStore.gridConfig)
                        
                        Rectangle()
                            .fill(isSelected ? Color.cyan : Color(white: 0.2))
                            .overlay(
                                Rectangle()
                                    .stroke(Color(white: 0.1), lineWidth: 1)
                            )
                            .shadow(color: isSelected ? .cyan.opacity(0.6) : .clear, radius: isSelected ? 8 : 0)
                            .frame(width: cellFrame.width, height: cellFrame.height)
                            .position(x: cellFrame.midX, y: cellFrame.midY)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        stack.updateFromDrag(
                            startLocation: value.startLocation,
                            currentLocation: value.location,
                            containerSize: geometry.size,
                            config: stackStore.gridConfig
                        )
                    }
            )
        }
    }
    
    private func isCellSelected(col: Int, row: Int) -> Bool {
        return col >= stack.startCol && col <= stack.endCol &&
               row >= stack.startRow && row <= stack.endRow
    }
}

struct StackSplitDialog: View {
    let parentStack: UserStack
    @Binding var isPresented: Bool
    
    @State private var mainStack: UserStack
    @State private var minorStack: UserStack
    @StateObject private var stackStore = StackStore.shared

    init(parentStack: UserStack, isPresented: Binding<Bool>) {
        self.parentStack = parentStack
        self._isPresented = isPresented
        // Default them to the parent's size
        self._mainStack = State(initialValue: UserStack(id: UUID(), name: nil, startCol: parentStack.startCol, startRow: parentStack.startRow, endCol: parentStack.endCol, endRow: parentStack.endRow, parentId: parentStack.id, isMain: true))
        self._minorStack = State(initialValue: UserStack(id: UUID(), name: nil, startCol: parentStack.startCol, startRow: parentStack.startRow, endCol: parentStack.endCol, endRow: parentStack.endRow, parentId: parentStack.id, isMain: false))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Split Stack")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack {
                    Text("Main Substack (*)")
                        .font(.subheadline)
                    StackGridSelectionView(stack: $mainStack)
                        .frame(width: 200, height: 130)
                        .background(Color(white: 0.1))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.3), lineWidth: 1))
                }
                
                VStack {
                    Text("Minor Substack")
                        .font(.subheadline)
                    StackGridSelectionView(stack: $minorStack)
                        .frame(width: 200, height: 130)
                        .background(Color(white: 0.1))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.3), lineWidth: 1))
                }
            }
            .padding(.bottom, 10)
            
            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                Button("Save Splits") {
                    stackStore.addStack(mainStack)
                    stackStore.addStack(minorStack)
                    isPresented = false
                }
                .buttonStyle(BorderedProminentButtonStyle())
            }
        }
        .padding()
        .frame(width: 480)
    }
}
