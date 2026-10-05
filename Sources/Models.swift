import Foundation
import AppKit
import Carbon

struct GridConfig: Codable, Equatable {
    var rows: Int
    var columns: Int
}

struct UserStack: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String?
    
    // Grid bounds (0-indexed)
    var startCol: Int
    var startRow: Int
    var endCol: Int
    var endRow: Int
    
    // Tree structure properties
    var parentId: UUID?
    var isMain: Bool
    
    init(id: UUID = UUID(), name: String? = nil, startCol: Int, startRow: Int, endCol: Int, endRow: Int, parentId: UUID? = nil, isMain: Bool = false) {
        self.id = id
        self.name = name
        self.startCol = startCol
        self.startRow = startRow
        self.endCol = endCol
        self.endRow = endRow
        self.parentId = parentId
        self.isMain = isMain
    }
    
    var rectRel: CGRect {
        // Unused temporarily while we transition. Kept for HotkeyStore tests.
        return .zero
    }

    func targetFrame(in screenFrame: CGRect, config: GridConfig) -> CGRect {
        let colWidth = screenFrame.width / CGFloat(config.columns)
        let rowHeight = screenFrame.height / CGFloat(config.rows)
        
        let minCol = min(startCol, endCol)
        let maxCol = max(startCol, endCol)
        let minRow = min(startRow, endRow)
        let maxRow = max(startRow, endRow)
        
        let width = CGFloat(maxCol - minCol + 1) * colWidth
        let height = CGFloat(maxRow - minRow + 1) * rowHeight
        
        return CGRect(
            x: screenFrame.minX + CGFloat(minCol) * colWidth,
            y: screenFrame.minY + CGFloat(minRow) * rowHeight,
            width: width,
            height: height
        )
    }

    mutating func updateFromDrag(
        startLocation: CGPoint, 
        currentLocation: CGPoint, 
        containerSize: CGSize, 
        config: GridConfig
    ) {
        let cols = config.columns
        let rows = config.rows
        
        let colWidth = cols > 0 ? containerSize.width / CGFloat(cols) : 10
        let rowHeight = rows > 0 ? containerSize.height / CGFloat(rows) : 10
        
        let startCol = max(0, min(cols - 1, Int(startLocation.x / colWidth)))
        let startRow = max(0, min(rows - 1, Int(startLocation.y / rowHeight)))
        
        let currentCol = max(0, min(cols - 1, Int(currentLocation.x / colWidth)))
        let currentRow = max(0, min(rows - 1, Int(currentLocation.y / rowHeight)))
        
        self.startCol = min(startCol, currentCol)
        self.endCol = max(startCol, currentCol)
        self.startRow = min(startRow, currentRow)
        self.endRow = max(startRow, currentRow)
    }

    static func cellFrame(col: Int, row: Int, containerSize: CGSize, config: GridConfig) -> CGRect {
        let cols = config.columns
        let rows = config.rows
        
        let colWidth = cols > 0 ? containerSize.width / CGFloat(cols) : 10
        let rowHeight = rows > 0 ? containerSize.height / CGFloat(rows) : 10
        
        return CGRect(
            x: CGFloat(col) * colWidth,
            y: CGFloat(row) * rowHeight,
            width: colWidth,
            height: rowHeight
        )
    }
}

struct Shortcut: Codable, Equatable {
    let keyCode: Int
    /// Storing as raw value for Codable
    let modifierFlagsRaw: UInt
    
    init(keyCode: Int, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifierFlagsRaw = modifiers.rawValue
    }
    
    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlagsRaw)
    }
    
    var description: String {
        var str = ""
        if modifiers.contains(.control) { str += "⌃" }
        if modifiers.contains(.option) { str += "⌥" }
        if modifiers.contains(.shift) { str += "⇧" }
        if modifiers.contains(.command) { str += "⌘" }
        
        // Very basic hardcoded conversions for prototype
        let keyString: String
        switch keyCode {
        case 123: keyString = "←"
        case 124: keyString = "→"
        case 125: keyString = "↓"
        case 126: keyString = "↑"
        default:
            if let chars = keycodeToString(CGKeyCode(keyCode)) {
                keyString = chars.uppercased()
            } else {
                keyString = "Key \(keyCode)"
            }
        }
        
        return str + keyString
    }
    
    private func keycodeToString(_ keyCode: CGKeyCode) -> String? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let layoutDataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        guard let layoutDataRef = layoutDataPtr else { return nil }
        let layoutData = unsafeBitCast(layoutDataRef, to: CFData.self)
        let keyLayout = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)
        
        var deadKeyState: UInt32 = 0
        let maxLength = 4
        var length = 0
        var chars = [UniChar](repeating: 0, count: maxLength)
        
        let status = UCKeyTranslate(
            keyLayout,
            keyCode,
            UInt16(kUCKeyActionDown),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            maxLength,
            &length,
            &chars
        )
        
        if status == noErr && length > 0 {
            return String(utf16CodeUnits: chars, count: length)
        }
        return nil
    }
}

struct StackRouter {
    static func determineDestination(for backgroundStack: UserStack, givenTarget targetStack: UserStack, in stacks: [UserStack]) -> UserStack {
        // Rule A: Merge Check - If backgroundStack is a strict descendant of targetStack
        if isDescendant(stack: backgroundStack, of: targetStack, stacks: stacks) {
            return targetStack
        }
        // Rule B: Split Check - If targetStack is a strict descendant of backgroundStack
        else if isDescendant(stack: targetStack, of: backgroundStack, stacks: stacks) {
            if let pathToT = path(from: backgroundStack, to: targetStack, stacks: stacks), pathToT.count > 1 {
                let parent = pathToT[0]
                let targetedChild = pathToT[1]
                
                // Route background windows to the opposite sibling of the branch the target window took
                if let oppositeChild = children(of: parent, in: stacks).first(where: { $0.id != targetedChild.id }) {
                    return oppositeChild
                }
            }
            return targetStack
        }
        return backgroundStack
    }

    static func isDescendant(stack: UserStack, of ancestor: UserStack, stacks: [UserStack]) -> Bool {
        var current = stack
        while let parentId = current.parentId {
            if parentId == ancestor.id { return true }
            if let next = stacks.first(where: { $0.id == parentId }) {
                current = next
            } else {
                break
            }
        }
        return false
    }

    static func path(from ancestor: UserStack, to descendant: UserStack, stacks: [UserStack]) -> [UserStack]? {
        var current = descendant
        var currPath = [current]
        
        while current.id != ancestor.id {
            guard let parentId = current.parentId,
                  let parent = stacks.first(where: { $0.id == parentId }) else {
                return nil
            }
            current = parent
            currPath.append(current)
        }
        return currPath.reversed()
    }
    
    static func children(of stack: UserStack, in stacks: [UserStack]) -> [UserStack] {
        return stacks.filter { $0.parentId == stack.id }
    }
}
