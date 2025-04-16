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
    var isVisible = false
    
    func show(appDelegate: AppDelegate) {
        print("FloatingWindowController.show() called, window exists: \(window != nil), current isVisible: \(isVisible)")
        if window == nil {
            print("Creating new floating window")
            createWindow(appDelegate: appDelegate)
        }
        
        if let window = window {
            // Position window before showing
            if let screenFrame = NSScreen.main?.visibleFrame {
                let windowFrame = window.frame
                let newOrigin = NSPoint(
                    x: screenFrame.maxX - windowFrame.width - 20,
                    y: screenFrame.maxY - windowFrame.height - 20
                )
                window.setFrameOrigin(newOrigin)
                print("Positioned window at: \(newOrigin)")
            }
            
            // Show window without activation
            window.orderFront(nil)
            isVisible = true
            print("Window ordered front, isVisible set to true, window.isVisible: \(window.isVisible)")
        } else {
            print("ERROR: Window is still nil after creation attempt")
        }
    }
    
    func hide() {
        print("FloatingWindowController.hide() called, window exists: \(window != nil), current isVisible: \(isVisible)")
        if let window = window {
            // Ensure window isn't key before hiding
            if window.isKeyWindow {
                print("Window is key, resigning key")
                window.resignKey()
            }
            window.orderOut(nil)
            print("Window ordered out")
        }
        isVisible = false
        print("isVisible set to false")
    }
    
    private func createWindow(appDelegate: AppDelegate) {
        print("Creating floating window")
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 400, height: 300)
        let windowRect = NSRect(x: screenRect.midX - 100, y: screenRect.midY - 200, width: 200, height: 400)
        
        let alwaysOnTop = UserDefaults.standard.bool(forKey: "alwaysOnTop")
        
        window = NonActivatingPanel(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        if let panel = window {
            panel.isFloatingPanel = true
            panel.becomesKeyOnlyIfNeeded = true
            panel.hidesOnDeactivate = false
            panel.level = alwaysOnTop ? .floating : .normal
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            print("Window created with level: \(panel.level.rawValue)")
        }
        
        window?.title = "Device Status"
        window?.isReleasedWhenClosed = false

        // Use the passed appDelegate directly - no need for guard let NSApp.delegate
        print("FloatingWindowController: Using passed AppDelegate instance.")

        // Create the floating view
        let floatingView = SimplifiedDeviceView(windowRef: window)
        // Create the hosting view, applying the modifier to the rootView
        print("FloatingWindowController: Creating NSHostingView with EnvironmentObject applied to root view.")
        let hostingView = NSHostingView(rootView: floatingView.environmentObject(appDelegate))
        window?.contentView = hostingView
        
        // Set window delegate to handle window closing
        windowDelegate = WindowDelegate(controller: self)
        window?.delegate = windowDelegate
        print("Window setup complete")
    }
}

// Window delegate to handle window closing
class WindowDelegate: NSObject, NSWindowDelegate {
    private weak var controller: FloatingWindowController?
    
    init(controller: FloatingWindowController) {
        self.controller = controller
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        controller?.isVisible = false
    }
    
    func windowDidResignKey(_ notification: Notification) {
        // Prevent the window from becoming key when it's not needed
        if let window = notification.object as? NSWindow {
            window.resignFirstResponder()
        }
    }
}
