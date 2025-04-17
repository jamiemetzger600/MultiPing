//
//  MenuBarController.swift
//  MultiPing
//
//  Created by Jamie Metzger on 4/6/25.
//


import Foundation
import AppKit
import SwiftUI

class MenuBarController: NSObject {
    static let shared = MenuBarController()
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var pingManager: PingManager?
    private var isCleanedUp = false
    
    override init() {
        super.init()
        print("MenuBarController: Initialized (without creating statusItem yet)")
        
        // Register for notifications about device list changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceListChanged),
            name: .deviceListChanged,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        cleanup()
    }
    
    @objc private func handleDeviceListChanged() {
        print("MenuBarController: Received device list changed notification")
        if let devices = pingManager?.devices {
            updateStatusItem(with: devices)
        }
    }
    
    func cleanup() {
        guard !isCleanedUp else { return }
        
        // Remove observer
        NotificationCenter.default.removeObserver(self)
        
        // Ensure we're on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.sync {
                self.performCleanup()
            }
        } else {
            performCleanup()
        }
    }
    
    private func performCleanup() {
        // Only cleanup if statusItem exists
        if let item = statusItem {
            print("MenuBarController: Performing cleanup")
            item.button?.subviews.forEach { $0.removeFromSuperview() }
            item.menu = nil
            item.button?.isHidden = true
            item.length = 0
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil // Nil out the reference
        }
        menu = nil
        pingManager = nil
        isCleanedUp = true
        print("MenuBarController: Cleanup finished")
    }
    
    func setup(with pingManager: PingManager) {
        print("MenuBarController: Setup called")
        self.pingManager = pingManager
        // Create statusItem lazily if it doesn't exist
        if statusItem == nil {
            print("MenuBarController: Creating NSStatusItem")
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            guard statusItem != nil else {
                print("ERROR: Failed to create status item!")
                return
            }
             print("MenuBarController: NSStatusItem created successfully")
            createStatusItemAppearance() // Setup appearance only once
            setupMenu() // Setup menu only once
        }
        show() // Ensure it's visible after setup
        updateStatusItem(with: pingManager.devices)
        print("MenuBarController: Setup complete")
    }
    
    // Renamed from createStatusItem to avoid confusion with lazy creation
    private func createStatusItemAppearance() {
         print("MenuBarController: Setting up status item appearance")
        statusItem?.button?.image = NSImage(systemSymbolName: "network", accessibilityDescription: "MultiPing")
        
        // Make the status bar item itself clickable to show the devices window
        statusItem?.button?.action = #selector(statusItemClicked)
        statusItem?.button?.target = self
    }
    
    @objc private func statusItemClicked() {
        print("MenuBarController: Status bar item clicked")
        showDevices()
    }
    
    private func setupMenu() {
        print("MenuBarController: Setting up menu")
        let newMenu = NSMenu()
        
        // Add prominent Show Devices menu item at the top
        let showDevicesItem = NSMenuItem(title: "Show Devices Window", action: #selector(showDevices), keyEquivalent: "d")
        showDevicesItem.target = self // Set target explicitly
        showDevicesItem.keyEquivalentModifierMask = [.command]
        newMenu.addItem(showDevicesItem)
        
        // Add Edit Devices as an alternative (keeping for backward compatibility)
        let editDevicesItem = NSMenuItem(title: "Edit Devices", action: #selector(showDevices), keyEquivalent: ",")
        editDevicesItem.target = self // Set target explicitly
        newMenu.addItem(editDevicesItem)
        
        newMenu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self // Set target explicitly
        newMenu.addItem(quitItem)
        
        self.menu = newMenu // Store reference if needed elsewhere
        statusItem?.menu = newMenu
    }
    
    @objc func showDevices() {
        print("MenuBarController: showDevices action triggered")
        // Ensure AppDelegate switches mode, which handles showing the window
        if let appDelegate = NSApp.delegate as? AppDelegate {
            print("MenuBarController: Found AppDelegate, calling switchMode")
            appDelegate.switchMode(to: "menuBar")
            
            // Directly access window manager to ensure window is shown
            print("MenuBarController: Directly showing main window")
            MainWindowManager.shared.showMainWindow()
        } else {
            print("MenuBarController: ERROR - Could not find AppDelegate")
        }
        
        // Ensure the app is activated
        print("MenuBarController: Activating application")
        NSApp.activate(ignoringOtherApps: true)
        
        // Additional direct attempt to find and show main window
        if let window = NSApp.windows.first(where: { $0.title == "Devices" }) {
            print("MenuBarController: Found main window, making it key and ordering front")
            window.makeKeyAndOrderFront(nil)
        } else {
            print("MenuBarController: Could not find main window by title")
        }
    }
    
    @objc func quitApp() { // Also remove private for consistency
        print("MenuBarController: quitApp action triggered")
        cleanup()
        NSApp.terminate(nil)
    }
    
    func updateStatusItem(with devices: [Device]) {
        // Ensure setup has been called and statusItem exists
        guard let statusItem = statusItem else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let capsuleRow = HStack(spacing: 6) {
                ForEach(devices) { device in
                    Text(device.name)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(device.isReachable ? Color.green : Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .padding(.horizontal, 6)

            let hostingView = NSHostingView(rootView: capsuleRow)
            hostingView.layout()
            let size = hostingView.fittingSize

            statusItem.length = size.width + 12 // Use the local statusItem
            statusItem.button?.subviews.forEach { $0.removeFromSuperview() }
            statusItem.button?.addSubview(hostingView)

            hostingView.translatesAutoresizingMaskIntoConstraints = false
            if let button = statusItem.button {
                NSLayoutConstraint.activate([
                    hostingView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                    hostingView.centerXAnchor.constraint(equalTo: button.centerXAnchor)
                ])
            }
            
            // Update menu with device status
            // Rebuild menu content if needed (or reuse existing menu items and update view)
            if let currentMenu = self.menu {
                // Find the custom view item and update it, or rebuild menu
                // For simplicity, let's rebuild if the device list changes significantly
                // or just update the existing view if possible.
                // Here we rebuild the custom part:
                
                // Remove old custom item if exists (assuming it's after the separator)
                if currentMenu.items.count > 2, currentMenu.items[2].view != nil {
                    currentMenu.removeItem(at: 2)
                }
                
                let capsuleRowView = NSHostingView(rootView:
                    HStack(spacing: 8) {
                        ForEach(devices) { device in
                            Text(device.name)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(device.isReachable ? Color.green : Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                )
                
                let customItem = NSMenuItem()
                customItem.view = capsuleRowView
                // Insert after separator at index 2
                 if currentMenu.items.count >= 2 {
                     currentMenu.insertItem(customItem, at: 2)
                 } else {
                     // Fallback if menu structure is unexpected
                     currentMenu.addItem(customItem)
                 }
            } else {
                // If menu somehow became nil, recreate it
                self.setupMenu()
            }
        }
    }
    
    func hide() {
        // Use optional chaining
        if statusItem != nil {
             print("MenuBarController: Hiding status item.")
             statusItem?.isVisible = false
        }
    }

    func show() {
        // Use optional chaining
        if statusItem != nil {
            print("MenuBarController: Showing status item.")
            statusItem?.isVisible = true
        }
    }
}
