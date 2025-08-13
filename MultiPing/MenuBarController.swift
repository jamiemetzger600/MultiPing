//
//  MenuBarController.swift
//  MultiPing
//
//  Created by Jamie Metzger on 4/6/25.
//


import Foundation
import AppKit
import SwiftUI
import Combine

class MenuBarController: NSObject {
    static let shared = MenuBarController()
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var pingManager: PingManager?
    private var isCleanedUp = false
    private var cancellables = Set<AnyCancellable>()
    
    // Opacity property with proper defaults
    private var menuBarOpacity: Double = UserDefaults.standard.double(forKey: "menuBarOpacity")
    
    override init() {
        // Initialize with a default opacity of 100% if not set
        if menuBarOpacity == 0 {
            menuBarOpacity = 1.0
            UserDefaults.standard.set(menuBarOpacity, forKey: "menuBarOpacity")
        }
        
        super.init()
        print("MenuBarController: Initialized with opacity: \(menuBarOpacity) (\(menuBarOpacity * 100)%)")
        
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
        
        // Cancel all subscriptions
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        
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
        print("MenuBarController: Setting up with PingManager")
        
        // Clean up any previous setup
        cleanup()
        
        self.pingManager = pingManager
        
        // Create status item in the menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Set up menu for status item
        setupMenu()
        
        // Set up notification observation for device updates instead of publisher
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceListChanged),
            name: .deviceListChanged,
            object: nil
        )
        
        // Initial update with current devices
        updateStatusItem(with: pingManager.devices)
    }
    
    private func setupMenu() {
        print("MenuBarController: Setting up menu")
        
        guard let statusItem = statusItem else {
            print("MenuBarController: Status item not available for menu setup")
            return
        }
        
        let menu = buildMenu()
        statusItem.menu = menu
        self.menu = menu
        
        // Set up right-click menu if needed
        if let button = statusItem.button {
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        print("MenuBarController: Menu setup complete")
    }
    
    func updateStatusItem(with devices: [Device]) {
        // Skip if no status item
        guard let statusItem = statusItem else {
            print("MenuBarController: Status item not available for update")
            return
        }
        
        // Skip if no devices to show
        guard !devices.isEmpty else {
            if let button = statusItem.button {
                button.title = "No Devices"
            }
            return
        }
        
        DispatchQueue.main.async {
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
            .opacity(self.menuBarOpacity)

            let hostingView = NSHostingView(rootView: capsuleRow)
            hostingView.layout()
            let size = hostingView.fittingSize

            statusItem.length = size.width + 12 // Use the local statusItem
            statusItem.button?.subviews.forEach { $0.removeFromSuperview() }
            statusItem.button?.addSubview(hostingView)
            
            // Apply opacity to button as well as the view inside
            statusItem.button?.alphaValue = CGFloat(self.menuBarOpacity)

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
                    .opacity(1.0) // Menu items should remain visible
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
        if let item = statusItem {
            print("MenuBarController: Hiding status item.")
            item.isVisible = false
            // For extra safety, try setting a very small length
            item.length = 0
        }
    }

    func show() {
        // Use optional chaining
        if let item = statusItem {
            print("MenuBarController: Showing status item.")
            item.isVisible = true
            // Reset length if needed
            if item.length == 0 {
                item.length = NSStatusItem.variableLength
                // Re-apply the devices if available
                if let devices = pingManager?.devices {
                    updateStatusItem(with: devices)
                }
            }
        } else {
            // If statusItem is nil, try to setup again
            if let pingManager = pingManager {
                setup(with: pingManager)
            }
        }
    }
    
    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        
        // Title item
        let titleItem = menu.addItem(withTitle: "MultiPing", action: nil, keyEquivalent: "")
        titleItem.attributedTitle = NSAttributedString(
            string: "MultiPing",
            attributes: [
                .font: NSFont.menuFont(ofSize: 14),
                .foregroundColor: NSColor.labelColor
            ]
        )
        
        menu.addItem(NSMenuItem.separator())
        
        // Add main actions
        let showDevicesItem = menu.addItem(withTitle: "Show Devices Window", action: #selector(showDevices), keyEquivalent: "")
        showDevicesItem.target = self
        
        let findDevicesItem = menu.addItem(withTitle: "Find Devices on Network", action: #selector(showFindDevicesWindow), keyEquivalent: "")
        findDevicesItem.target = self
        
        // Keep only the Toggle Floating Window menu item
        let toggleFloatingWindowItem = menu.addItem(withTitle: "Toggle Floating Window", action: #selector(toggleFloatingWindow), keyEquivalent: "")
        toggleFloatingWindowItem.target = self
        
        // Add opacity submenu for menu bar only
        let opacityMenuItem = NSMenuItem(title: "Menu Bar Opacity", action: nil, keyEquivalent: "")
        let opacitySubmenu = NSMenu()
        
        // Create opacity percentage options
        for percentage in stride(from: 100, through: 0, by: -10) {
            let percentItem = NSMenuItem(title: "\(percentage)%", action: #selector(setOpacity(_:)), keyEquivalent: "")
            percentItem.tag = percentage
            percentItem.target = self
            
            // Mark the current opacity setting
            let currentPercentage = Int(menuBarOpacity * 100)
            if currentPercentage == percentage || 
               (percentage == 100 && currentPercentage > 95) || // Handle rounding
               (percentage == 0 && currentPercentage < 5) {    // Handle rounding
                percentItem.state = .on
            }
            
            opacitySubmenu.addItem(percentItem)
        }
        
        opacityMenuItem.submenu = opacitySubmenu
        menu.addItem(opacityMenuItem)
        
        // Add a separator before app control items
        menu.addItem(NSMenuItem.separator())
        
        // Settings option
        let settingsItem = menu.addItem(withTitle: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        
        // Quit option
        let quitItem = menu.addItem(withTitle: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        
        return menu
    }
    
    @objc func showDevices() {
        print("MenuBarController: showDevices action triggered")
        if let appDelegate = NSApp.delegate as? AppDelegate {
            // Use switchMode instead of openWindow
            appDelegate.switchMode(to: "menuBar")
            
            // Ensure main window is shown - access directly since it's not optional
            DispatchQueue.main.async {
                appDelegate.mainWindowManager.showMainWindow()
            }
        }
    }
    
    @objc func showFindDevicesWindow() {
        print("MenuBarController: showFindDevicesWindow action triggered")
        
        // Try multiple approaches to ensure the window opens
        
        // First approach: Use the window controller specifically created for this
        FindDevicesWindowController.shared.show()
        
        // Ensure the app is activated
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // Method to toggle between menubar and floating window modes
    @objc func toggleFloatingWindow() {
        print("MenuBarController: toggleFloatingWindow action triggered")
        if let appDelegate = NSApp.delegate as? AppDelegate {
            // If current mode is menuBar, switch to floatingWindow and vice versa
            let newMode = appDelegate.currentMode == "menuBar" ? "floatingWindow" : "menuBar"
            print("MenuBarController: Switching mode to \(newMode)")
            
            // Use the centralized mode switching for both directions
            appDelegate.switchMode(to: newMode)
        }
    }
    
    // Method to handle opacity change selection
    @objc func setOpacity(_ sender: NSMenuItem) {
        let percentage = Double(sender.tag)
        let newOpacity = percentage / 100.0
        
        print("MenuBarController: Setting opacity to \(percentage)%")
        
        // Update the selected menu item
        if let opacitySubmenu = sender.menu {
            for item in opacitySubmenu.items {
                item.state = (item.tag == sender.tag) ? .on : .off
            }
        }
        
        // Save the new opacity
        menuBarOpacity = newOpacity
        UserDefaults.standard.set(newOpacity, forKey: "menuBarOpacity")
        UserDefaults.standard.synchronize() // Force immediate save
        
        // Update the display to apply new opacity
        if let devices = pingManager?.devices {
            updateStatusItem(with: devices)
        }
        
        // Also update button opacity directly
        statusItem?.button?.alphaValue = CGFloat(newOpacity)
    }
    
    @objc func showSettings() {
        print("MenuBarController: showSettings action triggered")
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.openSettings()
        }
    }
    
    @objc func quitApp() {
        print("MenuBarController: quitApp action triggered")
        cleanup()
        NSApp.terminate(nil)
    }
}
