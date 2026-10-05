import SwiftUI
import Cocoa

struct SpinOverlayView: View {
    let windows: [WindowSummary]
    let selectedIndex: Int
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                ForEach(0..<windows.count, id: \.self) { index in
                    let isSelected = index == selectedIndex
                    let window = windows[index]
                    
                    VStack {
                        if let thumbnail = window.thumbnail {
                            Image(nsImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 200, maxHeight: 150)
                        } else if let app = NSRunningApplication(processIdentifier: window.pid), let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                        } else {
                            // Fallback icon
                            Image(systemName: "macwindow")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(12)
                    .background(Color.clear)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 3)
                            .shadow(color: isSelected ? Color.cyan.opacity(0.8) : Color.clear, radius: 8)
                    )
                }
            }
            
            if selectedIndex >= 0 && selectedIndex < windows.count {
                Text(windows[selectedIndex].ownerName)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
            }
        }
        .padding(24)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.5), radius: 20)
        .preferredColorScheme(.dark)
    }
}

// Helper to use NSVisualEffectView in SwiftUI
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

class SpinOverlayWindowController: NSWindowController {
    convenience init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 150),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .floating
        panel.center() // Initial center, will usually be overridden
        
        self.init(window: panel)
    }
    
    func show(windows: [WindowSummary], selectedIndex: Int, screen: NSScreen?) {
        let overlayView = SpinOverlayView(windows: windows, selectedIndex: selectedIndex)
        let hostingView = NSHostingView(rootView: overlayView)
        hostingView.frame = NSRect(x: 0, y: 0, width: max(400, CGFloat(windows.count * 100)), height: 150)
        
        guard let window = self.window else { return }
        window.contentView = hostingView
        window.setContentSize(hostingView.fittingSize)
        
        if let screen = screen {
            // Center in the provided screen
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            let x = screenFrame.midX - windowFrame.width / 2
            let y = screenFrame.midY - windowFrame.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }
        
        window.orderFront(nil)
    }
    
    func hide() {
        window?.orderOut(nil)
    }
}
