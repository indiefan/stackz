import Foundation
import Cocoa
import SwiftUI
import Combine
import Combine

class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { return false }
    override var canBecomeMain: Bool { return false }
    
    // Crucial: This prevents macOS from auto-clamping our padded border 
    // to the visible edge of the screen, which was shifting the window down!
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}

class ActiveStackOverlayManager {
    static let shared = ActiveStackOverlayManager()
    
    private var window: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        SZLog("ActiveStackOverlayManager initialized")
        setupWindow()
        
        StackStore.shared.$activeStackState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.updateOverlay(for: newState)
            }
            .store(in: &cancellables)
            
        StackStore.shared.$stacks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshCurrentOverlay()
            }
            .store(in: &cancellables)
            
        StackStore.shared.$gridConfig
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshCurrentOverlay()
            }
            .store(in: &cancellables)
    }
    
    private func setupWindow() {
        let panel = OverlayPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        self.window = panel
    }
    
    private func refreshCurrentOverlay() {
        updateOverlay(for: StackStore.shared.activeStackState)
    }
    
    private func updateOverlay(for state: StackStore.ActiveStackState?) {
        guard StackStore.shared.showActiveStackBorder,
              let state = state,
              let stack = StackStore.shared.stacks.first(where: { $0.id == state.stackId }) else {
            window?.alphaValue = 0.0
            window?.orderOut(nil)
            return
        }
        
        // We now receive the exact mathematically resolved cgVisibleFrame from the match event!
        // No more recalculating the screen, completely preventing multi-monitor race conditions.
        let cgVisibleFrame = state.screenVisibleFrame
        let targetFrame = stack.targetFrame(in: cgVisibleFrame, config: StackStore.shared.gridConfig)
        
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 1080
        let padding: CGFloat = 30.0
        let appKitFrame = NSRect(
            x: targetFrame.minX - padding,
            y: (primaryScreenHeight - targetFrame.maxY) - padding,
            width: targetFrame.width + padding * 2,
            height: targetFrame.height + padding * 2
        )
        
        let animateBorder = StackStore.shared.animateActiveStackBorder
        
        if let existingHostingView = window?.contentView as? NSHostingView<ActiveStackOverlayView> {
            existingHostingView.rootView = ActiveStackOverlayView(padding: padding, animate: animateBorder)
            existingHostingView.frame = NSRect(origin: .zero, size: appKitFrame.size)
            window?.setFrame(appKitFrame, display: true)
        } else {
            let overlayView = ActiveStackOverlayView(padding: padding, animate: animateBorder)
            let hostingView = NSHostingView(rootView: overlayView)
            hostingView.frame = NSRect(origin: .zero, size: appKitFrame.size)
            
            window?.contentView = hostingView
            window?.setFrame(appKitFrame, display: true)
        }
        
        // Show instantly without fade
        if window?.isVisible == false || (window?.alphaValue ?? 0) < 1.0 {
            window?.alphaValue = 1.0
            window?.orderFront(nil)
        }
    }
}

struct ActiveStackOverlayView: View {
    let padding: CGFloat
    let animate: Bool
    
    var body: some View {
        GeometryReader { geo in
            let innerRect = CGRect(x: padding, y: padding, width: geo.size.width - padding * 2, height: geo.size.height - padding * 2)
            
            if animate {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    
                    ZStack {
                        // WLED Blends Inspired Flame Layers
                        ZStack {
                            // Base flow: High-frequency continuous blue/pink blend chasing CW
                            FlameLayer(
                                t: t, 
                                rotationSpeed: 180, 
                                colors: [
                                    Color(red: 1.0, green: 0.4, blue: 0.8).opacity(0.8),  // Light Hot Pink
                                    Color(red: 0.0, green: 0.1, blue: 1.0).opacity(0.8),  // Rich Blue
                                    Color(red: 0.6, green: 0.0, blue: 1.0).opacity(0.8),  // Purple blend
                                    Color(red: 0.0, green: 0.1, blue: 1.0).opacity(0.8),  // Rich Blue
                                    Color(red: 1.0, green: 0.4, blue: 0.8).opacity(0.8),  // Light Hot Pink
                                    Color(red: 0.0, green: 0.1, blue: 1.0).opacity(0.8),  // Rich Blue
                                    Color(red: 0.6, green: 0.0, blue: 1.0).opacity(0.8),  // Purple blend
                                    Color(red: 0.0, green: 0.1, blue: 1.0).opacity(0.8),  // Rich Blue
                                    Color(red: 1.0, green: 0.4, blue: 0.8).opacity(0.8)   // Light Hot Pink
                                ], 
                                baseWidth: 8, 
                                widthVar: 1, 
                                breatheSpeed: 2, 
                                blur: 3, 
                                padding: padding
                            )
                            
                            // Counter-current highlight: Brighter sparks dancing CCW
                            FlameLayer(
                                t: t, 
                                rotationSpeed: -260, 
                                colors: [
                                    .clear, 
                                    Color(red: 0.2, green: 0.4, blue: 1.0).opacity(0.7),  // Bright Blue High
                                    .clear, 
                                    Color(red: 1.0, green: 0.5, blue: 0.9).opacity(0.7),  // Lighter Pink High
                                    .clear,
                                    Color(red: 0.2, green: 0.4, blue: 1.0).opacity(0.7),  // Bright Blue High
                                    .clear, 
                                    Color(red: 1.0, green: 0.5, blue: 0.9).opacity(0.7),  // Lighter Pink High
                                    .clear
                                ], 
                                baseWidth: 11, 
                                widthVar: 2, 
                                breatheSpeed: 1.5, 
                                blur: 6, 
                                padding: padding
                            )
                            
                            // Outer Atmosphere: Slow blooming glow
                            FlameLayer(
                                t: t, 
                                rotationSpeed: 110, 
                                colors: [
                                    Color(red: 0.0, green: 0.0, blue: 0.9).opacity(0.5),  // Rich Dark Blue
                                    .clear, 
                                    Color(red: 0.8, green: 0.1, blue: 0.6).opacity(0.5),  // Deep Pink
                                    .clear, 
                                    Color(red: 0.0, green: 0.0, blue: 0.9).opacity(0.5),  // Rich Dark Blue
                                    .clear, 
                                    Color(red: 0.8, green: 0.1, blue: 0.6).opacity(0.5),  // Deep Pink
                                    .clear, 
                                    Color(red: 0.0, green: 0.0, blue: 0.9).opacity(0.5)   // Rich Dark Blue
                                ], 
                                baseWidth: 20, 
                                widthVar: 3, 
                                breatheSpeed: 3, 
                                blur: 12, 
                                padding: padding
                            )
                        }
                        .mask(
                            Path { path in
                                path.addRect(CGRect(origin: .zero, size: geo.size))
                                path.addRoundedRect(in: innerRect, cornerSize: CGSize(width: 12, height: 12), style: .continuous)
                            }
                            .fill(style: FillStyle(eoFill: true))
                        )
                        
                        // Fixed inner edge (crisp neon core)
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color(red: 0.6, green: 0.2, blue: 1.0).opacity(0.8), lineWidth: 2)
                            .shadow(color: Color(red: 0.3, green: 0.1, blue: 0.8).opacity(0.6), radius: 3)
                            .padding(padding)
                    }
                }
            } else {
                // Static Purple Border (Matches crisp neon core)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color(red: 0.6, green: 0.2, blue: 1.0).opacity(0.8), lineWidth: 2)
                    .shadow(color: Color(red: 0.3, green: 0.1, blue: 0.8).opacity(0.6), radius: 3)
                    .padding(padding)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

struct FlameLayer: View {
    let t: Double
    let rotationSpeed: Double
    let colors: [Color]
    let baseWidth: CGFloat
    let widthVar: CGFloat
    let breatheSpeed: Double
    let blur: CGFloat
    let padding: CGFloat
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: colors),
                    center: .center,
                    angle: .degrees(t * rotationSpeed)
                ),
                lineWidth: baseWidth + CGFloat(sin(t * breatheSpeed)) * widthVar
            )
            .blur(radius: blur)
            .padding(padding)
    }
}
