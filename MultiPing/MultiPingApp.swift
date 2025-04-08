// MultiPingApp.swift
// Menu bar now adjusts width to fit capsule buttons for each device name

import SwiftUI
import AppKit
import Combine

@main
struct MultiPingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            DeviceListView()
                .frame(minHeight: 500)
                .background {
                    Color.clear
                        .task {
                            if let window = NSApplication.shared.windows.first {
                                window.title = "Devices"
                                // Configure the window that SwiftUI creates
                                window.titlebarAppearsTransparent = true
                                window.titleVisibility = .hidden
                                window.toolbarStyle = .unifiedCompact
                                
                                // Store this window reference in AppDelegate
                                if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                    appDelegate.configureMainWindow(window)
                                }
                            }
                        }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 280, height: 500)
        .windowToolbarStyle(.unifiedCompact)
    }
}

// Move AppDelegate to this file to ensure it's in scope
@objc class AppDelegate: NSObject, NSApplicationDelegate, ModeSwitching {
    private var menuBarController: MenuBarController?
    var statusItem: NSStatusItem!
    var pingManager = PingManager.shared
    var cancellable: AnyCancellable?
    private var mainWindow: NSWindow? {
        willSet {
            // Remove observers from old window
            if let oldWindow = mainWindow {
                NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: oldWindow)
                NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: oldWindow)
            }
        }
    }
    
    // Add constants for UserDefaults keys
    private let windowFrameKey = "MainWindowFrame"
    
    deinit {
        // Clean up observers
        if let window = mainWindow {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: window)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: window)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set default interface mode to menuBar and ensure it's visible
        UserDefaults.standard.register(defaults: [
            "preferredInterface": "menuBar"
        ])
        
        // Initialize menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true  // Ensure visibility
        setupCustomMenuBarView()
        updateMenu()

        // Set up device updates
        cancellable = pingManager.$devices
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.setupCustomMenuBarView()
                self?.updateMenu()
            }

        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [self] _ in
            self.pingManager.pingAll { updated in
                self.setupCustomMenuBarView()
                if updated.contains(where: { !$0.isReachable }) {
                    NSApp.requestUserAttention(.criticalRequest)
                }
            }
        }
        
        // Switch to the saved mode (this will handle showing/hiding windows appropriately)
        let savedMode = UserDefaults.standard.string(forKey: "preferredInterface") ?? "menuBar"
        switchMode(to: savedMode)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func showMenuBar() {
        statusItem.isVisible = true
        setupCustomMenuBarView()
        updateMenu()
        
        // Ensure menu is properly set up
        if statusItem.menu == nil {
            updateMenu()
        }
    }
    
    func hideMenuBar() {
        statusItem.isVisible = false
    }
    
    func configureMainWindow(_ window: NSWindow) {
        mainWindow = window
        setupWindowFrameHandling(window)
        
        // Restore saved frame if it exists
        if let dict = UserDefaults.standard.dictionary(forKey: windowFrameKey) as? [String: CGFloat] {
            window.setFrame(NSRect(
                x: dict["x"] ?? 0,
                y: dict["y"] ?? 0,
                width: dict["width"] ?? 280,
                height: dict["height"] ?? 500
            ), display: true)
        } else {
            window.center()
        }
    }

    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        
        if let window = mainWindow {
            // Restore the saved frame before showing
            if let dict = UserDefaults.standard.dictionary(forKey: windowFrameKey) as? [String: CGFloat] {
                window.setFrame(NSRect(
                    x: dict["x"] ?? 0,
                    y: dict["y"] ?? 0,
                    width: dict["width"] ?? 280,
                    height: dict["height"] ?? 500
                ), display: true)
            }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }
        
        // If we don't have a window reference, look for it
        if let window = NSApp.windows.first(where: { $0.title == "Devices" }) {
            // Restore the saved frame before showing
            if let dict = UserDefaults.standard.dictionary(forKey: windowFrameKey) as? [String: CGFloat] {
                window.setFrame(NSRect(
                    x: dict["x"] ?? 0,
                    y: dict["y"] ?? 0,
                    width: dict["width"] ?? 280,
                    height: dict["height"] ?? 500
                ), display: true)
            }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            configureMainWindow(window)
        }
    }
    
    func hideMainWindow() {
        if let window = mainWindow ?? NSApp.windows.first(where: { $0.title == "Devices" }) {
            window.orderOut(nil)
        }
    }
    
    @objc func openSettings() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            
            // First ensure we're in menu bar mode
            self.switchMode(to: "menuBar")
            
            // Make sure we're showing the main window properly
            if let window = self.mainWindow ?? NSApp.windows.first(where: { $0.title == "Devices" }) {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            } else {
                self.showMainWindow()
            }
        }
    }

    func setupCustomMenuBarView() {
        let capsuleRow = HStack(spacing: 6) {
            ForEach(pingManager.devices) { device in
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

        statusItem.length = size.width + 12
        statusItem.button?.subviews.forEach { $0.removeFromSuperview() }
        statusItem.button?.addSubview(hostingView)

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.centerYAnchor.constraint(equalTo: statusItem.button!.centerYAnchor),
            hostingView.centerXAnchor.constraint(equalTo: statusItem.button!.centerXAnchor)
        ])
    }

    func updateMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Edit Devices", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())

        let capsuleRowView = NSHostingView(rootView:
            HStack(spacing: 8) {
                ForEach(pingManager.devices) { device in
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
        menu.addItem(customItem)

        statusItem.menu = menu
    }

    // Add the ModeSwitching protocol implementation
    func switchMode(to mode: String) {
        // Save the current window frame before switching modes
        if let window = mainWindow {
            saveWindowFrame()
        }
        
        switch mode {
        case "menuBar":
            // First hide floating window
            FloatingWindowController.shared.hide()
            // Then show menu bar and main window
            showMenuBar()
            showMainWindow()
        case "floatingWindow":
            // First hide menu bar and main window
            hideMenuBar()
            hideMainWindow()
            // Then show floating window
            FloatingWindowController.shared.show()
        case "cli":
            FloatingWindowController.shared.hide()
            hideMenuBar()
            hideMainWindow()
            CLIRunner.shared.start()
        default:
            break
        }
        
        // Save the selected mode
        UserDefaults.standard.set(mode, forKey: "preferredInterface")
    }

    private func setupWindowFrameHandling(_ window: NSWindow) {
        // Remove any existing observers first
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: window)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: window)
        
        // Add new observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize(_:)),
            name: NSWindow.didResizeNotification,
            object: window
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove(_:)),
            name: NSWindow.didMoveNotification,
            object: window
        )
        
        // Set window delegate to handle window closing
        window.delegate = self
    }
    
    @objc internal func windowDidResize(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === mainWindow {
            saveWindowFrame()
        }
    }
    
    @objc internal func windowDidMove(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === mainWindow {
            saveWindowFrame()
        }
    }
    
    private func saveWindowFrame() {
        guard let window = mainWindow else { return }
        let frame = window.frame
        let dict: [String: CGFloat] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.size.width,
            "height": frame.size.height
        ]
        UserDefaults.standard.set(dict, forKey: windowFrameKey)
    }
    
    private func getSavedWindowFrame() -> NSRect {
        if let dict = UserDefaults.standard.dictionary(forKey: windowFrameKey) as? [String: CGFloat] {
            return NSRect(
                x: dict["x"] ?? 0,
                y: dict["y"] ?? 0,
                width: dict["width"] ?? 280,
                height: dict["height"] ?? 500
            )
        }
        return NSRect(x: 0, y: 0, width: 280, height: 500)
    }
}

// Add window delegate methods
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === mainWindow {
            // Save the frame before the window closes
            saveWindowFrame()
            
            // Remove observers
            NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: window)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: window)
        }
    }
}
