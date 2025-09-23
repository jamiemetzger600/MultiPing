////
//  FloatingWindowController.swift
//  MultiPing
//
//  Created by Jamie Metzger on 4/6/25.
//


import Cocoa
import SwiftUI

// Custom panel that cannot become key or main window
class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool {
        return false
    }
    
    override var canBecomeMain: Bool {
        return false
    }
}

class FloatingWindowController {
    static let shared = FloatingWindowController()
    private var window: NonActivatingPanel?
    private var windowDelegate: WindowDelegate?
    var appDelegate: AppDelegate? // Make accessible to WindowDelegate
    var isVisible = false
    private let windowFrameKey = "FloatingWindowFrame"
    
    // Add property to track opacity
    private var windowOpacity: Double {
        get {
            return UserDefaults.standard.double(forKey: "floatingWindowOpacity")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "floatingWindowOpacity")
            applyOpacity()
        }
    }
    
    func show(appDelegate: AppDelegate) {
        print("FloatingWindowController.show() called, window exists: \(window != nil), current isVisible: \(isVisible)")
        
        // Store the AppDelegate reference
        self.appDelegate = appDelegate
        
        // If window was closed by the user (e.g., exists but is nil), recreate it
        if window == nil || (window != nil && !window!.isVisible) {
            print("Creating new floating window or recreating after user close")
            createWindow(appDelegate: appDelegate)
        }
        
        if let window = window {
            // Try to restore saved position first
            if let savedFrame = frameFromUserDefaults() {
                print("Restoring floating window frame from UserDefaults: \(savedFrame)")
                window.setFrame(savedFrame, display: false)
            } 
            // Default position if no saved frame
            else if let screenFrame = NSScreen.main?.visibleFrame {
                let windowFrame = window.frame
                let newOrigin = NSPoint(
                    x: screenFrame.maxX - windowFrame.width - 20,
                    y: screenFrame.maxY - windowFrame.height - 20
                )
                window.setFrameOrigin(newOrigin)
                print("Positioned window at default position: \(newOrigin)")
                
                // Save this initial position
                saveWindowFrame(window)
            }
            
            // Show window without activation
            window.orderFront(nil)
            isVisible = true
            print("Window ordered front, isVisible set to true, window.isVisible: \(window.isVisible)")
            
            // Apply opacity
            applyOpacity()
            
            // Ensure the window is actually visible by making it key if needed
            if !window.isVisible {
                print("FloatingWindowController: Window not visible after ordering front, trying makeKeyAndOrderFront")
                window.makeKeyAndOrderFront(nil)
            }
        } else {
            print("ERROR: Window is still nil after creation attempt")
        }
    }
    
    func hide() {
        print("FloatingWindowController.hide() called, window exists: \(window != nil), current isVisible: \(isVisible)")
        if let window = window {
            // Save position before hiding
            saveWindowFrame(window)
            
            // Ensure window isn't key before hiding
            if window.isKeyWindow {
                print("Window is key, resigning key")
                window.resignKey()
            }
            
            // Force immediate ordering out
            window.orderOut(nil)
            print("Window ordered out")
        }
        isVisible = false
        print("isVisible set to false")
    }
    
    func forceHide() {
        print("FloatingWindowController: Force hiding and resetting floating window")
        
        // Save frame if possible
        if let window = window {
            saveWindowFrame(window)
            
            // Force window to hide
            window.orderOut(nil)
            
            // Release references to window and its contents
            window.contentView = nil
        }
        
        // Reset references
        window = nil
        windowDelegate = nil
        isVisible = false
        
        print("FloatingWindowController: Force hiding complete")
    }
    
    // Helper to load frame from UserDefaults
    private func frameFromUserDefaults() -> NSRect? {
        guard let dict = UserDefaults.standard.dictionary(forKey: windowFrameKey) as? [String: CGFloat],
              let x = dict["x"], let y = dict["y"], let width = dict["width"], let height = dict["height"] else {
            return nil
        }
        
        // Basic validation for size
        guard width >= 150 && height >= 200 else { return nil }
        
        // Ensure the frame is on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            // Adjust position if off-screen
            let adjustedX = min(max(x, screenFrame.origin.x), screenFrame.maxX - width)
            let adjustedY = min(max(y, screenFrame.origin.y), screenFrame.maxY - height)
            
            return NSRect(x: adjustedX, y: adjustedY, width: width, height: height)
        }
        
        return NSRect(x: x, y: y, width: width, height: height)
    }
    
    // Helper to save frame to UserDefaults
    fileprivate func saveWindowFrame(_ window: NSWindow) {
        let frame = window.frame
        
        // Basic validation
        guard frame.width >= 150 && frame.height >= 200 else { return }
        
        let dict: [String: CGFloat] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.width,
            "height": frame.height
        ]
        print("Saving floating window frame to UserDefaults: \(dict)")
        UserDefaults.standard.set(dict, forKey: windowFrameKey)
        UserDefaults.standard.synchronize() // Force immediate write
    }
    
    // Add a method to check if the window is still visible after a potential user close
    func checkWindowVisibility() {
        // If window exists but is not visible, it might have been closed by the user
        if let window = window, !window.isVisible {
            print("FloatingWindowController: Window appears to have been closed by the user")
            isVisible = false
            
            // Switch back to menu bar mode
            DispatchQueue.main.async {
                if let appDelegate = self.appDelegate {
                    print("FloatingWindowController: Switching to menu bar mode via checkWindowVisibility")
                    appDelegate.switchMode(to: "menuBar")
                } else {
                    print("FloatingWindowController: ERROR - No AppDelegate reference in checkWindowVisibility")
                }
            }
        }
    }
    
    // Update the window creation to add a timer to periodically check visibility
    private func createWindow(appDelegate: AppDelegate) {
        print("Creating floating window")
        
        // Try to get saved frame first
        var windowRect: NSRect
        if let savedFrame = frameFromUserDefaults() {
            windowRect = savedFrame
            print("Using saved frame for floating window: \(windowRect)")
        } else {
            // Default size and position if no saved frame
            let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 400, height: 300)
            windowRect = NSRect(x: screenRect.midX - 100, y: screenRect.midY - 200, width: 200, height: 400)
            print("Using default frame for floating window: \(windowRect)")
        }
        
        let alwaysOnTop = UserDefaults.standard.bool(forKey: "alwaysOnTop")
        
        // Create a new panel with the proper style mask to ensure it behaves as a standalone window
        // and doesn't affect other UI elements
        window = NonActivatingPanel(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: true // Use defer:true to avoid immediate loading
        )
        
        if let panel = window {
            // Configure panel to be standalone and not interfere with other UI
            panel.isFloatingPanel = true
            panel.becomesKeyOnlyIfNeeded = true
            panel.hidesOnDeactivate = false
            panel.level = alwaysOnTop ? .statusBar : .normal
            
            // Set alpha value during creation
            let opacity = UserDefaults.standard.double(forKey: "floatingWindowOpacity")
            panel.alphaValue = CGFloat(opacity > 0 ? opacity : 1.0)
            
            // IMPORTANT: Only use auxiliary behavior to avoid affecting main window
            panel.collectionBehavior = .fullScreenAuxiliary
            
            print("Window created with level: \(panel.level.rawValue), opacity: \(panel.alphaValue)")
            
            // Use a DIFFERENT autosave name to avoid conflict with main window
            panel.setFrameAutosaveName("floatingDeviceWindow")
            print("Set frameAutosaveName to 'floatingDeviceWindow'")
            
            // Set a distinct title for easier debugging
            panel.title = "MultiPing - Floating Status"
            panel.isReleasedWhenClosed = false
        }

        // Use the passed appDelegate directly
        print("FloatingWindowController: Using passed AppDelegate instance.")

        // Create the floating view
        let floatingView = SimplifiedDeviceView(windowRef: window)
        
        // Create the hosting view with environment object applied
        print("FloatingWindowController: Creating NSHostingView with EnvironmentObject applied")
        let hostingView = NSHostingView(rootView: floatingView.environmentObject(appDelegate))
        
        // Set content view AFTER window is fully configured
        window?.contentView = hostingView
        
        // Set delegate AFTER window configuration
        windowDelegate = WindowDelegate(controller: self)
        window?.delegate = windowDelegate
        
        print("FloatingWindowController: Window setup complete")
    }
    
    // Add opacity control method
    func setOpacity(_ opacity: Double) {
        let clampedOpacity = min(1.0, max(0.1, opacity))
        print("FloatingWindowController: Setting opacity to \(clampedOpacity)")
        
        // Save to windowOpacity property which triggers didSet
        windowOpacity = clampedOpacity
        
        // Also directly apply opacity to window to ensure immediate visual effect
        if let window = window {
            window.alphaValue = CGFloat(clampedOpacity)
            print("FloatingWindowController: Directly applied opacity \(clampedOpacity) to window")
        }
    }
    
    // Method to apply opacity to window
    private func applyOpacity() {
        if let window = window {
            // Default to 1.0 if no value is stored
            let opacity = windowOpacity > 0 ? windowOpacity : 1.0
            print("FloatingWindowController: Applying opacity \(opacity) to window")
            window.alphaValue = CGFloat(opacity)
        }
    }
    
    // Method to set window level
    func setAlwaysOnTop(_ alwaysOnTop: Bool) {
        print("FloatingWindowController: Setting alwaysOnTop to \(alwaysOnTop)")
        if let window = window {
            if alwaysOnTop {
                // Use .statusBar level to ensure it stays above all other windows
                window.level = .statusBar
                print("Window level set to: .statusBar (\(window.level.rawValue))")
            } else {
                window.level = .normal
                print("Window level set to: .normal (\(window.level.rawValue))")
            }
        }
    }
}

// Update WindowDelegate to save position when window moves or closes
class WindowDelegate: NSObject, NSWindowDelegate {
    private weak var controller: FloatingWindowController?
    
    init(controller: FloatingWindowController) {
        self.controller = controller
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            // Save position before closing
            controller?.saveWindowFrame(window)
        }
        controller?.isVisible = false
        
        // Switch back to menu bar mode when the floating window is closed
        DispatchQueue.main.async { [self] in
            print("FloatingWindowController: Window was closed by user, switching to menu bar mode")
            if let appDelegate = controller?.appDelegate {
                print("FloatingWindowController: Successfully got AppDelegate, switching to menuBar mode")
                appDelegate.switchMode(to: "menuBar")
            } else {
                print("FloatingWindowController: ERROR - No AppDelegate reference available")
            }
        }
    }
    
    func windowDidResignKey(_ notification: Notification) {
        // Prevent the window from becoming key when it's not needed
        if let window = notification.object as? NSWindow {
            window.resignFirstResponder()
        }
    }
    
    func windowDidMove(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            controller?.saveWindowFrame(window)
        }
    }
    
    func windowDidResize(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            controller?.saveWindowFrame(window)
        }
    }
}
