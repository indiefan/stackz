import Foundation
import Cocoa

struct WindowSummary: Equatable {
    let windowId: CGWindowID
    let ownerName: String
    let pid: pid_t
    let thumbnail: NSImage?
}

class ZOrderLookup {
    static func findHighestWindow(in rect: CGRect, ignoring ignoredId: CGWindowID?, strictMatch: Bool = true) -> CGWindowID? {
        // Find highest window by grabbing the first item from the filtered array
        let allWindows = findAllWindows(in: rect, strictMatch: strictMatch)
        return allWindows.first(where: { $0.windowId != ignoredId })?.windowId
    }
    
    static func findAllWindows(in rect: CGRect, strictMatch: Bool = true) -> [WindowSummary] {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowListInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as NSArray? else {
            return []
        }
        
        var foundWindows: [WindowSummary] = []
        
        for info in windowListInfo {
            guard let windowInfo = info as? [String: Any] else { continue }
            guard let layer = windowInfo[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            
            guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
            
            guard let windowId = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
                  let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t else { continue }
            
            if strictMatch {
                if bounds.isStrictlyEqual(to: rect) {
                    foundWindows.append(WindowSummary(windowId: windowId, ownerName: ownerName, pid: pid, thumbnail: captureThumbnail(for: windowId)))
                }
            } else {
                let intersection = bounds.intersection(rect)
                let area = intersection.width * intersection.height
                let requiredArea = min(rect.width * rect.height, bounds.width * bounds.height) * 0.5
                
                if area > requiredArea {
                    foundWindows.append(WindowSummary(windowId: windowId, ownerName: ownerName, pid: pid, thumbnail: captureThumbnail(for: windowId)))
                }
            }
        }
        
        return foundWindows
    }
    
    static func findUnstackedWindows(on screen: NSScreen, stacks: [UserStack], config: GridConfig) -> [WindowSummary] {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowListInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as NSArray? else {
            return []
        }
        
        var foundWindows: [WindowSummary] = []
        let screenFrame = screen.cgVisibleFrame
        let stackFrames = stacks.map { $0.targetFrame(in: screenFrame, config: config) }
        
        for info in windowListInfo {
            guard let windowInfo = info as? [String: Any] else { continue }
            guard let layer = windowInfo[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            
            guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
            
            // Must be loosely on this screen
            guard screenFrame.contains(bounds.centerPoint) else { continue }
            
            // Must NOT strictly match any user stack
            let isStacked = stackFrames.contains { $0.isStrictlyEqual(to: bounds) }
            if isStacked { continue }
            
            guard let windowId = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
                  let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t else { continue }
            
            foundWindows.append(WindowSummary(windowId: windowId, ownerName: ownerName, pid: pid, thumbnail: captureThumbnail(for: windowId)))
        }
        
        return foundWindows
    }
    
    private static func captureThumbnail(for windowId: CGWindowID) -> NSImage? {
        let options = CGWindowListOption(arrayLiteral: .optionIncludingWindow)
        if let cgImage = CGWindowListCreateImage(.null, options, windowId, .boundsIgnoreFraming) {
            return NSImage(cgImage: cgImage, size: NSZeroSize)
        }
        return nil
    }
}
