import Foundation
import Cocoa

class WindowManager {
    static let shared = WindowManager()
    
    private init() {
        SZLog("WindowManager initialized")
        NotificationCenter.default.addObserver(self, selector: #selector(handleShortcutTriggered(_:)), name: .shortcutTriggered, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleScreenParametersChanged(_:)), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(handleWakeOrLoginNotification(_:)), name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(handleWakeOrLoginNotification(_:)), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
    }
    
    @objc private func handleScreenParametersChanged(_ notification: Notification) {
        if StackStore.shared.autoSortOnDisplayChange {
            SZLog("Monitor configuration changed, automatically sorting into stacks...")
            sortIntoStacks()
        }
    }
    
    @objc private func handleWakeOrLoginNotification(_ notification: Notification) {
        if StackStore.shared.autoSortOnWake {
            SZLog("Wake/Login event detected, automatically sorting into stacks...")
            sortIntoStacks()
        }
    }
    
    @objc private func handleShortcutTriggered(_ notification: Notification) {
        SZLog("WindowManager received shortcut trigger: \(notification.userInfo ?? [:])")
        guard let userInfo = notification.userInfo,
              let action = userInfo["action"] as? ActionType else {
            SZLog("Invalid shortcut trigger parameters")
            return
        }
        
        if action == .sendToNextMonitor {
            SZLog("Executing action: \(action)")
            sendToNextMonitor()
            return
        }
        
        if action == .swapToNextMonitor {
            SZLog("Executing action: \(action)")
            swapToNextMonitor()
            return
        }
        
        if action == .selectNextMonitor {
            SZLog("Executing action: \(action)")
            selectNextMonitor()
            return
        }
        
        if action == .globalSpin {
            SZLog("Executing action: \(action)")
            globalSpin()
            return
        }
        
        if action == .sortIntoStacks {
            SZLog("Executing action: \(action)")
            sortIntoStacks()
            return
        }
        
        guard let stackIdStr = userInfo["stackId"] as? String,
              let stackId = UUID(uuidString: stackIdStr),
              let stack = StackStore.shared.stacks.first(where: { $0.id == stackId }) else {
            SZLog("Stack deleted or invalid")
            return
        }
        SZLog("Executing action: \(action) for stack: \(stack.id)")
        
        switch action {
        case .send:
            sendToStack(stack)
        case .swap:
            swapWithStack(stack)
        case .selectFocus:
            selectStack(stack)
        case .spin:
            spinStack(stack)
        case .sendToNextMonitor:
            break
        case .swapToNextMonitor:
            break
        case .selectNextMonitor:
            break
        case .globalSpin:
            break
        case .sortIntoStacks:
            break
        }
    }
    
    private func getFrontier(for node: UserStack, in stacks: [UserStack], occupied: Set<UUID>) -> [UserStack] {
        let store = StackStore.shared
        let descendants = store.descendants(of: node)
        
        let hasOccupiedDescendant = descendants.contains { occupied.contains($0.id) }
        
        if hasOccupiedDescendant {
            let children = store.children(of: node)
            var frontier: [UserStack] = []
            for child in children {
                frontier.append(contentsOf: getFrontier(for: child, in: stacks, occupied: occupied))
            }
            return frontier
        } else {
            return [node]
        }
    }
    
    private func sortIntoStacks() {
        SZLog("sortIntoStacks called for all monitors")
        
        let gridConfig = StackStore.shared.gridConfig
        let stacks = StackStore.shared.stacks
        
        for screen in NSScreen.screens {
            let cgVisibleFrame = screen.cgVisibleFrame
            
            // Find occupied stacks on this screen
            let allWindows = ZOrderLookup.findAllWindows(in: cgVisibleFrame, strictMatch: false)
            var occupiedStackIds = Set<UUID>()
            
            for win in allWindows {
                guard let element = AccessibilityElement.getWindowElement(win.windowId) else { continue }
                let windowFrame = element.frame
                for stack in stacks {
                    let sFrame = stack.targetFrame(in: cgVisibleFrame, config: gridConfig)
                    if sFrame.isStrictlyEqual(to: windowFrame) {
                        occupiedStackIds.insert(stack.id)
                    }
                }
            }
            
            // Generate valid frontier stacks
            let rootStacks = stacks.filter { $0.parentId == nil }
            var validStacks: [UserStack] = []
            for root in rootStacks {
                validStacks.append(contentsOf: getFrontier(for: root, in: stacks, occupied: occupiedStackIds))
            }
            
            guard !validStacks.isEmpty else {
                SZLog("No valid stacks found to sort into for screen \(screen.localizedName).")
                continue
            }
            
            // Get all unstacked windows strictly on this screen
            let unstackedWindows = ZOrderLookup.findUnstackedWindows(on: screen, stacks: stacks, config: gridConfig)
            
            guard !unstackedWindows.isEmpty else {
                SZLog("No unstacked windows found to sort on screen \(screen.localizedName).")
                continue
            }
            
            for win in unstackedWindows {
                guard let element = AccessibilityElement.getWindowElement(win.windowId) else { continue }
                let windowFrame = element.frame
                let windowCenter = windowFrame.centerPoint
                
                // Find nearest valid stack
                var nearestStack: UserStack?
                var minDistance: CGFloat = .greatestFiniteMagnitude
                
                for stack in validStacks {
                    let stackFrame = stack.targetFrame(in: cgVisibleFrame, config: gridConfig)
                    let stackCenter = stackFrame.centerPoint
                    
                    let dx = windowCenter.x - stackCenter.x
                    let dy = windowCenter.y - stackCenter.y
                    let distance = (dx * dx) + (dy * dy) // No need to square root for comparison
                    
                    if distance < minDistance {
                        minDistance = distance
                        nearestStack = stack
                    }
                }
                
                if let bestStack = nearestStack {
                    let targetFrame = bestStack.targetFrame(in: cgVisibleFrame, config: gridConfig)
                    SZLog("Sorting window \(win.windowId) (\(win.ownerName)) into stack \(bestStack.id)")
                    element.setFrame(targetFrame)
                    // We specifically do NOT bringToFront to preserve existing z-order
                }
            }
        }
    }
    
    func getActiveScreen() -> NSScreen {
        guard let frontWindowElement = AccessibilityElement.getFrontWindowElement() else {
            return NSScreen.main ?? NSScreen.screens[0]
        }
        
        let windowFrame = frontWindowElement.frame
        var maxIntersectionArea: CGFloat = 0
        var bestScreen: NSScreen = NSScreen.main ?? NSScreen.screens[0]
        
        for screen in NSScreen.screens {
            let intersection = screen.cgFrame.intersection(windowFrame)
            let area = intersection.width * intersection.height
            
            if area > maxIntersectionArea {
                maxIntersectionArea = area
                bestScreen = screen
            }
        }
        
        return bestScreen
    }
    
    private func sendToStack(_ stack: UserStack) {
        SZLog("sendToStack called")
        guard let frontWindow = AccessibilityElement.getFrontWindowElement() else {
            SZLog("Failed to get front window element")
            return
        }
        
        let targetScreen = getActiveScreen()
        let cgVisibleFrame = targetScreen.cgVisibleFrame
        let targetFrame = stack.targetFrame(in: cgVisibleFrame, config: StackStore.shared.gridConfig)
        
        // Dynamic Routing: Route background windows based on tree split/merge rules
        routeBackgroundWindows(targetStack: stack, activeWindowId: frontWindow.windowId, activeScreen: targetScreen)
        
        frontWindow.setFrame(targetFrame)
        frontWindow.bringToFront()
    }
    
    private func routeBackgroundWindows(targetStack: UserStack, activeWindowId: CGWindowID?, activeScreen: NSScreen) {
        let stacks = StackStore.shared.stacks
        let gridConfig = StackStore.shared.gridConfig
        let screenFrame = activeScreen.cgVisibleFrame
        
        let allWindows = ZOrderLookup.findAllWindows(in: screenFrame, strictMatch: false)
        
        // Process back-to-front or just standard? Reversing helps avoid z-fighting on overlaps, but let's just go through.
        for win in allWindows.reversed() {
            if win.windowId == activeWindowId { continue }
            
            // Determine current strict stack S for this background window
            var currentStack: UserStack? = nil
            let wFrameOptional = AccessibilityElement.getWindowElement(win.windowId)?.frame
            guard let windowFrame = wFrameOptional else { continue }
            
            for stack in stacks {
                let sFrame = stack.targetFrame(in: screenFrame, config: gridConfig)
                if sFrame.isStrictlyEqual(to: windowFrame) {
                    currentStack = stack
                    break
                }
            }
            
            guard let S = currentStack else { continue }
            
            let dest = StackRouter.determineDestination(for: S, givenTarget: targetStack, in: stacks)
            
            if dest.id != S.id {
                let destFrame = dest.targetFrame(in: screenFrame, config: gridConfig)
                if let element = AccessibilityElement.getWindowElement(win.windowId) {
                    element.setFrame(destFrame)
                }
            }
        }
    }
    
    private func swapWithStack(_ targetStack: UserStack) {
        SZLog("swapWithStack called for target: \(targetStack.id)")
        guard let frontWindow = AccessibilityElement.getFrontWindowElement() else {
            SZLog("Failed to get front window element")
            return
        }
        
        let targetScreen = getActiveScreen()
        let cgVisibleFrame = targetScreen.cgVisibleFrame
        let currentWindowFrame = frontWindow.frame
        let gridConfig = StackStore.shared.gridConfig
        
        let targetStackFrame = targetStack.targetFrame(in: cgVisibleFrame, config: gridConfig)
        
        // 1. Check if the current window matches ANY defined user stack's bounds
        let isCurrentWindowInAStack = StackStore.shared.stacks.contains { stack in
            let stackFrame = stack.targetFrame(in: cgVisibleFrame, config: gridConfig)
            return stackFrame.isStrictlyEqual(to: currentWindowFrame)
        }
        
        if !isCurrentWindowInAStack {
            SZLog("Current window is not strictly sized to a known stack. Falling back to sendToStack.")
            sendToStack(targetStack)
            return
        }
        
        // If the current window is already roughly taking up the target stack, we don't swap.
        if targetStackFrame.contains(currentWindowFrame.centerPoint) {
            SZLog("Current window is already in the target stack. Nothing to swap.")
            return
        }
        
        // 2. Find highest window in target stack
        guard let windowToSwapId = ZOrderLookup.findHighestWindow(in: targetStackFrame, ignoring: frontWindow.windowId) else {
            SZLog("No window found in target stack to swap with. Falling back to sendToStack behavior.")
            sendToStack(targetStack)
            return
        }
        
        guard let windowToSwapElement = AccessibilityElement.getWindowElement(windowToSwapId) else {
            SZLog("Could not get accessibility element for the target window.")
            return
        }
        
        // 3. Check if the target window actually matches the target stack strictly
        let targetWindowFrame = windowToSwapElement.frame
        if !targetStackFrame.isStrictlyEqual(to: targetWindowFrame) {
            SZLog("Target window in stack does not strictly match the stack bounds. Falling back to sendToStack.")
            sendToStack(targetStack)
            return
        }
        
        // Perform geometric swap
        windowToSwapElement.setFrame(currentWindowFrame)
        frontWindow.setFrame(targetStackFrame)
        
        // Bring target window to front so it maintains focus after the swap
        windowToSwapElement.bringToFront()
    }
    
    private func getDestinationStack(for sourceWindowFrame: CGRect?, sourceScreen: NSScreen, targetScreen: NSScreen) -> (root: UserStack?, largestOccupied: UserStack?) {
        let gridConfig = StackStore.shared.gridConfig
        let stacks = StackStore.shared.stacks
        let sourceVisFrame = sourceScreen.cgVisibleFrame
        let targetVisFrame = targetScreen.cgVisibleFrame
        
        // 1. Find root stack definition
        var resolvedRoot: UserStack? = nil
        
        // Try to match active window logically to a stack first
        if let frame = sourceWindowFrame {
            for stack in stacks {
                if stack.targetFrame(in: sourceVisFrame, config: gridConfig).isStrictlyEqual(to: frame) {
                    var current = stack
                    while let parentId = current.parentId, let parent = stacks.first(where: { $0.id == parentId }) {
                        current = parent
                    }
                    resolvedRoot = current
                    break
                }
            }
        }
        
        // Fallback to absolute first root if no window match
        if resolvedRoot == nil {
            resolvedRoot = stacks.first(where: { $0.parentId == nil })
        }
        
        guard let root = resolvedRoot else { return (nil, nil) }
        
        // 2. Build default descendant path
        var path: [UserStack] = [root]
        var current = root
        while let mainChild = StackStore.shared.children(of: current).first(where: { $0.isMain }) {
            path.append(mainChild)
            current = mainChild
        }
        
        // 3. Check occupancy on destination monitor (largest to smallest)
        var largestOccupied: UserStack? = nil
        let allWindowsOnTarget = ZOrderLookup.findAllWindows(in: targetVisFrame, strictMatch: false)
        let elementCache = allWindowsOnTarget.compactMap { AccessibilityElement.getWindowElement($0.windowId) }
        
        for stack in path {
            let stackFrame = stack.targetFrame(in: targetVisFrame, config: gridConfig)
            let isOccupied = elementCache.contains { $0.frame.isStrictlyEqual(to: stackFrame) }
            
            if isOccupied {
                largestOccupied = stack
                break
            }
        }
        
        return (root, largestOccupied)
    }
    
    private func sendToNextMonitor() {
        SZLog("sendToNextMonitor called")
        guard let frontWindow = AccessibilityElement.getFrontWindowElement() else {
            SZLog("Failed to get front window element")
            return
        }
        
        let screens = NSScreen.screens
        guard screens.count > 1 else {
            SZLog("Only one screen detected, cannot send to next monitor.")
            return
        }
        
        let activeScreen = getActiveScreen()
        guard let currentIndex = screens.firstIndex(of: activeScreen) else { return }
        let nextIndex = (currentIndex + 1) % screens.count
        let nextScreen = screens[nextIndex]
        
        let resolution = getDestinationStack(for: frontWindow.frame, sourceScreen: activeScreen, targetScreen: nextScreen)
        
        guard let root = resolution.root else {
            SZLog("No stacks configured.")
            return
        }
        
        let targetStack = resolution.largestOccupied ?? root
        let targetVisFrame = nextScreen.cgVisibleFrame
        let targetFrame = targetStack.targetFrame(in: targetVisFrame, config: StackStore.shared.gridConfig)
        
        routeBackgroundWindows(targetStack: targetStack, activeWindowId: frontWindow.windowId, activeScreen: nextScreen)
        
        frontWindow.setFrame(targetFrame)
        frontWindow.bringToFront()
    }
    
    private func swapToNextMonitor() {
        SZLog("swapToNextMonitor called")
        guard let frontWindow = AccessibilityElement.getFrontWindowElement() else {
            SZLog("Failed to get front window element")
            return
        }
        
        let screens = NSScreen.screens
        guard screens.count > 1 else {
            SZLog("Only one screen detected, cannot swap with next monitor.")
            return
        }
        
        let activeScreen = getActiveScreen()
        guard let currentIndex = screens.firstIndex(of: activeScreen) else { return }
        
        // Wrap around to first monitor if we are at the end
        let nextIndex = (currentIndex + 1) % screens.count
        let nextScreen = screens[nextIndex]
        
        let currentVisFrame = activeScreen.cgVisibleFrame
        let nextVisFrame = nextScreen.cgVisibleFrame
        let currentWindowFrame = frontWindow.frame
        let gridConfig = StackStore.shared.gridConfig
        
        // 1. Check if the current window matches ANY defined user stack's bounds
        var matchedStack: UserStack? = nil
        for stack in StackStore.shared.stacks {
            let stackFrame = stack.targetFrame(in: currentVisFrame, config: gridConfig)
            if stackFrame.isStrictlyEqual(to: currentWindowFrame) {
                matchedStack = stack
                break
            }
        }
        
        guard let targetStack = matchedStack else {
            SZLog("Current window is not strictly sized to a known stack. Falling back to sendToNextMonitor.")
            sendToNextMonitor()
            return
        }
        
        // Calculate where this stack exists on the NEXT monitor
        let targetStackFrameOnNextMonitor = targetStack.targetFrame(in: nextVisFrame, config: gridConfig)
        
        // 2. Find highest active window physically inside the equivalent stack space on the target monitor
        guard let windowToSwapId = ZOrderLookup.findHighestWindow(in: targetStackFrameOnNextMonitor, ignoring: frontWindow.windowId) else {
            SZLog("No window found in target stack on next monitor to swap with. Falling back to sendToNextMonitor behavior.")
            sendToNextMonitor()
            return
        }
        
        guard let windowToSwapElement = AccessibilityElement.getWindowElement(windowToSwapId) else {
            SZLog("Could not get accessibility element for the target window.")
            return
        }
        
        // 3. Ensure the target window strictly conforms to the stack's boundaries 
        let targetWindowFrame = windowToSwapElement.frame
        if !targetStackFrameOnNextMonitor.isStrictlyEqual(to: targetWindowFrame) {
            SZLog("Target window on next monitor does not strictly match the stack bounds. Falling back to sendToNextMonitor.")
            sendToNextMonitor()
            return
        }
        // 4. Perform proportional swap calculating exact floating point mappings to prevent cascade and retina bounds snapping
        let relFwX = (currentWindowFrame.minX - currentVisFrame.minX) / currentVisFrame.width
        let relFwY = (currentWindowFrame.minY - currentVisFrame.minY) / currentVisFrame.height
        let relFwW = currentWindowFrame.width / currentVisFrame.width
        let relFwH = currentWindowFrame.height / currentVisFrame.height
        
        let fwTarget = CGRect(
            x: nextVisFrame.minX + (relFwX * nextVisFrame.width),
            y: nextVisFrame.minY + (relFwY * nextVisFrame.height),
            width: relFwW * nextVisFrame.width,
            height: relFwH * nextVisFrame.height
        )

        let relSwX = (targetWindowFrame.minX - nextVisFrame.minX) / nextVisFrame.width
        let relSwY = (targetWindowFrame.minY - nextVisFrame.minY) / nextVisFrame.height
        let relSwW = targetWindowFrame.width / nextVisFrame.width
        let relSwH = targetWindowFrame.height / nextVisFrame.height
        
        let swTarget = CGRect(
            x: currentVisFrame.minX + (relSwX * currentVisFrame.width),
            y: currentVisFrame.minY + (relSwY * currentVisFrame.height),
            width: relSwW * currentVisFrame.width,
            height: relSwH * currentVisFrame.height
        )
        
        windowToSwapElement.setFrame(swTarget)
        frontWindow.setFrame(fwTarget)
        
        // Bring newly swapped window up to keep focus continuity visually for the user
        windowToSwapElement.bringToFront()
    }
    
    private func selectNextMonitor() {
        SZLog("selectNextMonitor called")
        guard let frontWindow = AccessibilityElement.getFrontWindowElement() else {
            SZLog("Failed to get front window element. Identifying absolute occupied default.")
            executeSelectNextMonitor(sourceFrame: nil)
            return
        }
        executeSelectNextMonitor(sourceFrame: frontWindow.frame)
    }
    
    private func executeSelectNextMonitor(sourceFrame: CGRect?) {
        let screens = NSScreen.screens
        guard screens.count > 1 else {
            SZLog("Only one screen detected, cannot select next monitor.")
            return
        }
        
        let activeScreen = getActiveScreen()
        guard let currentIndex = screens.firstIndex(of: activeScreen) else { return }
        let nextIndex = (currentIndex + 1) % screens.count
        let nextScreen = screens[nextIndex]
        
        let resolution = getDestinationStack(for: sourceFrame, sourceScreen: activeScreen, targetScreen: nextScreen)
        
        guard let targetStack = resolution.largestOccupied else {
            SZLog("No occupied default descendant stack on next monitor strictly matched. Silently failing.")
            return
        }
        
        let targetVisFrame = nextScreen.cgVisibleFrame
        let targetStackFrame = targetStack.targetFrame(in: targetVisFrame, config: StackStore.shared.gridConfig)
        
        guard let windowToSelectId = ZOrderLookup.findHighestWindow(in: targetStackFrame, ignoring: nil) else {
            SZLog("Occupied stack resolved but no accessible top window found.")
            return
        }
        
        guard let windowToSelectElement = AccessibilityElement.getWindowElement(windowToSelectId) else {
            SZLog("Could not get accessibility element for the target window.")
            return
        }
        
        SZLog("Successfully identified target window on next monitor tree. Bringing to front.")
        windowToSelectElement.bringToFront()
    }
    
    private func focusNextMonitorCenter() {
        let screens = NSScreen.screens
        guard screens.count > 1 else { return }
        
        let activeScreen = getActiveScreen()
        guard let currentIndex = screens.firstIndex(of: activeScreen) else { return }
        
        let nextIndex = (currentIndex + 1) % screens.count
        let nextScreen = screens[nextIndex]
        let nextVisFrame = nextScreen.cgVisibleFrame
        
        // We calculate the absolute center point of the next monitor to move the cursor to
        let centerPoint = CGPoint(
            x: nextVisFrame.midX,
            y: nextVisFrame.midY
        )
        
        if let event = CGEvent(source: nil) {
            let currentCursor = event.location
            SZLog("Moving cursor from \(currentCursor) to fallback center \(centerPoint)")
        }
        
        CGDisplayMoveCursorToPoint(CGMainDisplayID(), centerPoint)
    }
    
    private func selectStack(_ stack: UserStack) {
        SZLog("selectStack called")
        
        let targetScreen = getActiveScreen()
        let cgVisibleFrame = targetScreen.cgVisibleFrame
        let targetFrame = stack.targetFrame(in: cgVisibleFrame, config: StackStore.shared.gridConfig)
        
        guard let windowToSelectId = ZOrderLookup.findHighestWindow(in: targetFrame, ignoring: nil) else {
            SZLog("No window found in target stack to select focus.")
            return
        }
        
        guard let windowToSelectElement = AccessibilityElement.getWindowElement(windowToSelectId) else {
            SZLog("Could not get accessibility element for the target window.")
            return
        }
        
        windowToSelectElement.bringToFront()
    }
    
    private func spinStack(_ stack: UserStack) {
        SZLog("spinStack called, offloading to SpinSessionManager")
        let currentModifiers = NSEvent.modifierFlags
        SpinSessionManager.shared.spin(stack: stack, modifiers: currentModifiers)
    }
    
    private func globalSpin() {
        SZLog("globalSpin called")
        let currentModifiers = NSEvent.modifierFlags
        guard let frontWindowElement = AccessibilityElement.getFrontWindowElement() else {
            SZLog("No active window, ignoring global spin.")
            return
        }
        
        let currentWindowFrame = frontWindowElement.frame
        let activeScreen = getActiveScreen()
        let cgVisibleFrame = activeScreen.cgVisibleFrame
        let gridConfig = StackStore.shared.gridConfig
        let stacks = StackStore.shared.stacks
        
        // 1. Check if the currently active window matches a defined user stack strictly
        var matchedStack: UserStack? = nil
        for stack in stacks {
            let stackFrame = stack.targetFrame(in: cgVisibleFrame, config: gridConfig)
            if stackFrame.isStrictlyEqual(to: currentWindowFrame) {
                matchedStack = stack
                break
            }
        }
        
        // 2. If it's in a stack, perform a localized stack spin
        if let matchedStack = matchedStack {
            SZLog("Focused window matches stack \(matchedStack.id). Spinning that exact stack.")
            SpinSessionManager.shared.spin(stack: matchedStack, modifiers: currentModifiers)
            return
        }
        
        // 3. Otherwise, do a spin across all unstacked windows on the current screen
        SZLog("Focused window does not strictly match any stack. Executing unstacked spin.")
        let unstackedWindows = ZOrderLookup.findUnstackedWindows(on: activeScreen, stacks: stacks, config: gridConfig)
        
        guard !unstackedWindows.isEmpty else {
            SZLog("No unstacked windows found to spin.")
            return
        }
        
        SpinSessionManager.shared.spin(windows: unstackedWindows, screen: activeScreen, modifiers: currentModifiers)
    }
}

extension CGRect {
    var centerPoint: CGPoint {
        CGPoint(x: midX, y: midY)
    }
    
    // A strict equality check that allows for tiny floating point rounding differences
    func isStrictlyEqual(to other: CGRect, tolerance: CGFloat = 2.0) -> Bool {
        return abs(self.minX - other.minX) <= tolerance &&
               abs(self.minY - other.minY) <= tolerance &&
               abs(self.width - other.width) <= tolerance &&
               abs(self.height - other.height) <= tolerance
    }
}

extension NSScreen {
    /// Returns the screen's frame converted to CoreGraphics (top-left origin) coordinate space,
    /// relative to the primary display.
    var cgFrame: CGRect {
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? frame.height
        return CGRect(
            x: frame.minX,
            y: primaryScreenHeight - frame.maxY, // flip Y-axis relative to top screen
            width: frame.width,
            height: frame.height
        )
    }
    
    /// Returns the screen's visible frame (excluding menu bar and dock) converted to 
    /// CoreGraphics (top-left origin) coordinate space, relative to the primary display.
    var cgVisibleFrame: CGRect {
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? frame.height
        return CGRect(
            x: visibleFrame.minX,
            y: primaryScreenHeight - visibleFrame.maxY, // flip Y-axis relative to top screen
            width: visibleFrame.width,
            height: visibleFrame.height
        )
    }
}
