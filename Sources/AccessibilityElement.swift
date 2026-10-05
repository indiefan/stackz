//
//  AccessibilityElement.swift
//
//  Portions adapted from Rectangle (https://github.com/rxhanson/Rectangle),
//  Copyright (c) 2019-2026 Ryan Hanson, used under the MIT License.
//  See THIRD_PARTY_NOTICES.md.
//

import Foundation
import Cocoa

class AccessibilityElement {
    fileprivate let wrappedElement: AXUIElement
    
    init(_ element: AXUIElement) {
        wrappedElement = element
    }
    
    convenience init(_ pid: pid_t) {
        self.init(AXUIElementCreateApplication(pid))
    }
    
    private func getElementValue(_ attribute: NSAccessibility.Attribute) -> AccessibilityElement? {
        guard let value = wrappedElement.getValue(attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return AccessibilityElement(value as! AXUIElement)
    }
    
    private func getElementsValue(_ attribute: NSAccessibility.Attribute) -> [AccessibilityElement]? {
        guard let value = wrappedElement.getValue(attribute), let array = value as? [AXUIElement] else { return nil }
        return array.map { AccessibilityElement($0) }
    }
    
    private var role: NSAccessibility.Role? {
        guard let value = wrappedElement.getValue(.role) as? String else { return nil }
        return NSAccessibility.Role(rawValue: value)
    }
    
    private var isApplication: Bool? {
        guard let role = role else { return nil }
        return role == .application
    }
    
    var isWindow: Bool? {
        guard let role = role else { return nil }
        return role == .window
    }
    
    private var position: CGPoint? {
        get { wrappedElement.getWrappedValue(.position) }
        set {
            guard let newValue = newValue else { return }
            wrappedElement.setValue(.position, newValue)
        }
    }
    
    func isResizable() -> Bool {
        if let isResizable = wrappedElement.isValueSettable(.size) {
            return isResizable
        }
        return true
    }
    
    var size: CGSize? {
        get { wrappedElement.getWrappedValue(.size) }
        set {
            guard let newValue = newValue else { return }
            wrappedElement.setValue(.size, newValue)
        }
    }
    
    var frame: CGRect {
        guard let position = position, let size = size else { return .null }
        return .init(origin: position, size: size)
    }
    
    func setFrame(_ frame: CGRect) {
        // App accessibility can be finicky. Order of size vs origin matters depending on what screen it's moving across.
        // For simplicity in this prototype, set size, origin, then size again (handles moving to a smaller screen).
        size = frame.size
        position = frame.origin
        size = frame.size
    }
    
    var windowId: CGWindowID? {
        wrappedElement.getWindowId()
    }
    
    var pid: pid_t? {
        wrappedElement.getPid()
    }
    
    var windowElement: AccessibilityElement? {
        if isWindow == true { return self }
        return getElementValue(.window)
    }
    
    private var isMainWindow: Bool? {
        get { windowElement?.wrappedElement.getValue(.main) as? Bool }
        set {
            guard let newValue = newValue else { return }
            windowElement?.wrappedElement.setValue(.main, newValue)
        }
    }
    
    private var applicationElement: AccessibilityElement? {
        if isApplication == true { return self }
        guard let pid = pid else { return nil }
        return AccessibilityElement(pid)
    }
    
    var focusedWindowElement: AccessibilityElement? {
        applicationElement?.getElementValue(.focusedWindow)
    }
    
    var windowElements: [AccessibilityElement]? {
        applicationElement?.getElementsValue(.windows)
    }
    
    func bringToFront() {
        if isMainWindow != true {
            isMainWindow = true
        }
        AXUIElementPerformAction(wrappedElement, kAXRaiseAction as CFString)
        if let pid = pid, let app = NSRunningApplication(processIdentifier: pid) {
            app.activate(options: .activateIgnoringOtherApps)
        }
    }
}

extension AccessibilityElement {
    static func getFrontApplicationElement() -> AccessibilityElement? {
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.isActive && $0.bundleIdentifier != Bundle.main.bundleIdentifier
        }) else { return nil }
        return AccessibilityElement(app.processIdentifier)
    }
    
    static func getFrontWindowElement() -> AccessibilityElement? {
        SZLog("getFrontWindowElement called")
        SZLog("Is AX Trusted right now? \(AXIsProcessTrusted())")
        
        // Fast path: Ask the active application for its focused window directly.
        // This avoids race conditions with CGWindowListCopyWindowInfo lagging during intra-app window switches.
        if let appElement = getFrontApplicationElement(),
           let focusedWindow = appElement.focusedWindowElement {
            SZLog("Found active window via AX UI Element fast path.")
            return focusedWindow
        }
        
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            SZLog("Failed to get window list")
            return nil
        }
        
        // Find the absolute highest z-order window that belongs to a real app, not ourselves
        for windowInfo in windowList {
            guard let windowId = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let ownerName = windowInfo[kCGWindowOwnerName as String] as? String else { continue }
            
            // Ignore background system processes and Stackz
            if ownerName == "Stackz" || ownerName == "Window Server" || ownerName.contains("Notification") || ownerName == "Dock" || ownerName == "Finder" {
                continue
            }
            
            SZLog("Selected visually topmost window candidate: \(ownerName) (WindowID: \(windowId))")
            
            // Convert visual CGWindowID to an actionable AccessibilityElement
            if let activeWindow = AccessibilityElement.getWindowElement(windowId) {
                return activeWindow
            } else {
                SZLog("Window \(ownerName) has no valid accessibility element. Checking next topmost...")
            }
        }
        
        SZLog("No visually accessible windows found")
        return nil
    }
    
    static func getWindowElement(_ windowId: CGWindowID) -> AccessibilityElement? {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowListInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as NSArray? else { return nil }
        
        for info in windowListInfo {
            guard let windowInfo = info as? [String: Any] else { continue }
            guard let id = windowInfo[kCGWindowNumber as String] as? CGWindowID, id == windowId else { continue }
            guard let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t else { continue }
            
            let appElement = AccessibilityElement(pid)
            
            // Try standard window list first
            if let windows = appElement.windowElements {
                if let match = windows.first(where: { $0.windowId == windowId }) {
                    return match
                }
            }
            
            // Fallback: search all children for window role
            guard let children = appElement.getElementsValue(.children) else { return nil }
            for child in children {
                if child.role == .window && child.windowId == windowId {
                    return child
                }
            }
        }
        return nil
    }
}
