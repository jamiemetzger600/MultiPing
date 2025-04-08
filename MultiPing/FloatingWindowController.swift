////
//  FloatingWindowController.swift
//  MultiPing
//
//  Created by Jamie Metzger on 4/6/25.
//


import Cocoa
import SwiftUI

class FloatingWindowController {
    private var window: NSWindow?
    private var windowDelegate: WindowDelegate?
    var isVisible = false
    
    func show() {
        print("FloatingWindowController.show() called")
        if window == nil {
            print("Creating new floating window")
            createWindow()
        }
        
        if let window = window {
            print("Making window key and ordering front")
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            isVisible = true
            
            // Ensure the window is properly positioned and visible
            if let screenFrame = NSScreen.main?.visibleFrame {
                let windowFrame = window.frame
                let newOrigin = NSPoint(
                    x: screenFrame.maxX - windowFrame.width - 20,
                    y: screenFrame.maxY - windowFrame.height - 20
                )
                print("Positioning window at: \(newOrigin)")
                window.setFrameOrigin(newOrigin)
            }
        } else {
            print("ERROR: Window is nil after creation attempt")
        }
    }
    
    func hide() {
        print("FloatingWindowController.hide() called")
        window?.orderOut(nil)
        isVisible = false
    }
    
    func toggle() {
        print("FloatingWindowController.toggle() called, isVisible: \(isVisible)")
        if isVisible {
            hide()
        } else {
            show()
        }
    }
    
    private func createWindow() {
        print("Creating floating window")
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 400, height: 300)
        let windowRect = NSRect(x: screenRect.midX - 100, y: screenRect.midY - 200, width: 200, height: 400)
        
        let alwaysOnTop = UserDefaults.standard.bool(forKey: "alwaysOnTop")
        
        window = NSPanel(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        if let panel = window as? NSPanel {
            panel.isFloatingPanel = true
            panel.becomesKeyOnlyIfNeeded = true
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
        
        window?.title = "Device Status"
        window?.isReleasedWhenClosed = false
        window?.level = alwaysOnTop ? .floating : .normal
        
        print("Creating floating view")
        // Create the floating view with the window reference
        let floatingView = SimplifiedDeviceView(windowRef: window)
        let hostingView = NSHostingView(rootView: floatingView)
        window?.contentView = hostingView
        
        print("Setting up window delegate")
        // Set window delegate to handle window closing
        windowDelegate = WindowDelegate(controller: self)
        window?.delegate = windowDelegate
        
        print("Window creation complete")
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
        print("Window will close")
        controller?.isVisible = false
    }
}
