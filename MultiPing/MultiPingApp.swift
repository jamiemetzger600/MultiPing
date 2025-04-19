// MultiPingApp.swift
import SwiftUI
import AppKit // Ensure AppKit is imported for NSApplicationDelegate, NSWindow, etc.
import Foundation // Ensure Foundation is imported for Notification
import Combine

@main
struct MultiPingApp: App {
    // Use the App Delegate Adaptor
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            // Ensure DeviceListView is the content
            DeviceListView()
                .environmentObject(appDelegate) // Pass the delegate
        }
        .windowStyle(.hiddenTitleBar) // Keep style
        
        // Add Find Devices Window
        WindowGroup(id: "findDevices") {
            FindDevicesView()
                .environmentObject(appDelegate)
                .environmentObject(PingManager.shared)
                .onAppear {
                    // Apply window controller to configure the window
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let window = NSApp.windows.first(where: { $0.title == "Find Devices" || $0.title.contains("findDevices") }) {
                            FindDevicesWindowController.shared.configureFindDevicesWindow(window)
                        }
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .defaultPosition(.center)
        .defaultSize(CGSize(width: 650, height: 500))
        .commandsRemoved()
    }
}

// Keep AppDelegate definition in the same file
@objc class AppDelegate: NSObject, NSApplicationDelegate, ModeSwitching, ObservableObject {

    // MARK: - Published Properties
    @Published var currentMode: String = "menuBar" // Default mode

    // MARK: - Controllers and Managers (Ensure these exist)
    var menuBarController = MenuBarController.shared
    var pingManager = PingManager.shared
    var mainWindowManager = MainWindowManager.shared // Make public
    var floatingWindowController = FloatingWindowController.shared
    private var findDevicesWindowController = FindDevicesWindowController.shared

    // MARK: - Internal State
    var cancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var statusBarCleanupComplete = false

    // MARK: - Lifecycle
    override init() {
        super.init()
        // Observe and persist currentMode
        $currentMode
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { mode in
                print("Saving mode to UserDefaults: \(mode)")
                UserDefaults.standard.set(mode, forKey: "preferredInterface")
            }
            .store(in: &cancellables)
    }

    deinit {
        performCleanup()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("AppDelegate: applicationDidFinishLaunching")
        setupSignalHandling() // Ensure this method exists

        // Configure the main window if it exists
        if let window = NSApp.windows.first { // Use NSApp
            // First set frameAutosaveName for built-in persistence
            window.setFrameAutosaveName("mainWindow")
            print("AppDelegate: Set frameAutosaveName to 'mainWindow'")
            
            // Then use our manager for additional control
            mainWindowManager.configureMainWindow(window) // Use manager
        } else {
            print("AppDelegate: Error - Main window not found during launch.")
        }
        
        // Always start in menuBar mode for consistent behavior
        currentMode = "menuBar"
        print("AppDelegate: Initial mode set to \(currentMode)")

        // Setup UI for menuBar mode (don't use saved preference at launch)
        menuBarController.setup(with: pingManager) // Setup menu bar
        
        // Ensure floating window is hidden at launch
        floatingWindowController.hide()
        
        // Show the window during first launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Small delay to ensure window is properly loaded
            self.mainWindowManager.showMainWindow()
            // Only apply menuBar state at launch
            self.applyModeState(mode: "menuBar")
            print("AppDelegate: Initial mode UI applied after delay")
            
            // After initial launch, then we can restore the saved preference
            let savedMode = UserDefaults.standard.string(forKey: "preferredInterface") ?? "menuBar"
            if savedMode != "menuBar" {
                // Only switch if different from initial menuBar mode, and do it with a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.switchMode(to: savedMode)
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        performCleanup()
        Thread.sleep(forTimeInterval: 0.1) // Allow cleanup time
    }

    // Keep app running after last window closed (typical for menu bar apps)
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Setup Methods
    private func setupSignalHandling() {
        // Handle signals like SIGTERM for graceful shutdown
        signal(SIGTERM) { _ in
            if let delegate = NSApp.delegate as? AppDelegate {
                print("Received SIGTERM, performing cleanup.")
                delegate.performCleanup()
            }
            exit(0)
        }
        // Add other signal handling if needed (e.g., SIGHUP)
    }

    // MARK: - Mode Switching Core Logic
    func switchMode(to newMode: String) {
        print("====================================================================")
        print("AppDelegate: switchMode called with mode: \(newMode), current mode: \(currentMode)")
        
        guard newMode != currentMode else {
            print("AppDelegate: Mode \(newMode) is already active.")
            // Even if already in this mode, try to show the window
            if newMode == "menuBar" {
                print("AppDelegate: Already in menuBar mode, still showing main window.")
                mainWindowManager.showMainWindow()
            } else if newMode == "floatingWindow" {
                print("AppDelegate: Already in floatingWindow mode, still showing floating window.")
                floatingWindowController.show(appDelegate: self)
            }
            print("====================================================================")
            return
        }
        
        // Validate the requested mode
        guard ["menuBar", "floatingWindow", "cli"].contains(newMode) else {
            print("AppDelegate: Invalid mode requested: \(newMode)")
            print("====================================================================")
            return
        }

        print("AppDelegate: Switching mode from \(currentMode) to \(newMode)")
        
        // Use NSApp.windows to log current window state
        print("Current windows:")
        NSApp.windows.forEach { window in
            print("- Window: \(window.title), visible: \(window.isVisible), level: \(window.level.rawValue)")
        }
        
        // Handle specific FROM->TO transitions to prevent problems
        if currentMode == "floatingWindow" && newMode == "menuBar" {
            // When going from floating to menu bar, first hide the floating window
            print("AppDelegate: Special handling for floating->menuBar transition")
            floatingWindowController.hide()
            
            // Wait a moment, then update mode and show main window
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.currentMode = newMode
                self.menuBarController.setup(with: self.pingManager)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.mainWindowManager.showMainWindow()
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        } 
        else if currentMode == "menuBar" && newMode == "floatingWindow" {
            // When going from menu bar to floating, first hide the main window
            print("AppDelegate: Special handling for menuBar->floating transition")
            mainWindowManager.hideMainWindow()
            
            // Wait a moment, then update mode and show floating window
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.currentMode = newMode
                self.menuBarController.hide()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.floatingWindowController.show(appDelegate: self)
                }
            }
        }
        else {
            // For other transitions, use standard approach
            currentMode = newMode
            applyModeState(mode: newMode)
        }
        
        print("====================================================================")
    }

    private func applyModeState(mode: String) {
        print("AppDelegate: Applying UI state for mode \(mode)")
        
        // Ensure UI updates on main thread
        DispatchQueue.main.async {
            switch mode {
            case "menuBar":
                print("Applying menuBar state:")
                // First ensure floating window is hidden
                self.floatingWindowController.hide()
                
                // Then show menu bar
                self.menuBarController.setup(with: self.pingManager)
                self.menuBarController.show() // Explicitly show the menu bar
                
                // Finally show main window with delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.mainWindowManager.showMainWindow()
                    NSApp.activate(ignoringOtherApps: true)
                }
                
            case "floatingWindow":
                print("Applying floatingWindow state:")
                // First hide main window
                self.mainWindowManager.hideMainWindow()
                
                // Then hide menu bar
                self.menuBarController.hide()
                
                // Finally show floating window with delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.floatingWindowController.show(appDelegate: self)
                }
                
            case "cli":
                print("Applying cli state:")
                self.floatingWindowController.hide()
                self.menuBarController.hide()
                self.mainWindowManager.hideMainWindow()
                self.launchCliScript()
                
            default:
                print("Applying default (menuBar) state due to unknown mode: \(mode)")
                self.floatingWindowController.hide()
                self.menuBarController.setup(with: self.pingManager)
                self.menuBarController.show()
                self.mainWindowManager.showMainWindow()
            }
            
            print("AppDelegate: Finished applying UI state for mode \(mode)")
        }
    }

    // MARK: - CLI Script Launching (Ensure this matches your implementation)
    private func launchCliScript() {
        print("Attempting to launch cli.py")
        guard let scriptPath = Bundle.main.path(forResource: "cli", ofType: "py") else {
            print("Error: Could not find cli.py in the app bundle.")
            // Optionally switch back to a GUI mode on error
            DispatchQueue.main.async { self.switchMode(to: "menuBar") }
            return
        }
        print("Found cli.py at: \(scriptPath)")

        // --- IMPORTANT: Ensure this Python path is correct for the target system ---
        let pythonPath = "/Users/jamie/.pyenv/shims/python3" // Example Path - MUST BE VERIFIED

        // Use AppleScript to launch in Terminal
        let appleScriptSource = """
        set pyPath to quoted form of "\(pythonPath)"
        set scriptArg to quoted form of "\(scriptPath)"
        set commandToRun to pyPath & " " & scriptArg
        print("Final command for Terminal: " & commandToRun)

        tell application "Terminal"
            activate
            try
                do script commandToRun
            on error errMsg number errorNumber
                 log "AppleScript Execution Error: " & errMsg & " (" & errorNumber & ")"
            end try
        end tell
        """
        print("Generated AppleScript:\n\(appleScriptSource)")

        var errorDict: NSDictionary? = nil
        if let scriptObject = NSAppleScript(source: appleScriptSource) {
            if scriptObject.executeAndReturnError(&errorDict) != nil {
                print("AppleScript executed (check Terminal).")
            } else {
                print("AppleScript Execution Failed: \(errorDict ?? [:])")
                DispatchQueue.main.async { self.switchMode(to: "menuBar") } // Fallback
            }
        } else {
            print("Error: Could not create NSAppleScript object.")
            DispatchQueue.main.async { self.switchMode(to: "menuBar") } // Fallback
        }
    }

    // MARK: - Actions (Example: Open Settings/Main Window)
    @objc func openSettings() {
        print("AppDelegate: openSettings called")
        // Ensure main window is visible when settings are opened
        switchMode(to: "menuBar") // Switches mode, which should show main window
        DispatchQueue.main.async {
             NSApp.activate(ignoringOtherApps: true) // Bring app to front
        }
    }

    // MARK: - Cleanup Logic
    private func performCleanup() {
        guard !statusBarCleanupComplete else { return }
        print("AppDelegate: Performing cleanup")

        // Cancel Combine subscriptions
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        cancellable?.cancel() // Cancel any single cancellable
        cancellable = nil

        // Cleanup managers
        pingManager.cleanup() // Stop ping timer

        // Cleanup UI elements (ensure on main thread if needed)
        let cleanupTask = { [weak self] in
            print("AppDelegate: Cleaning up status bar controller")
            self?.menuBarController.cleanup() // Cleanup menu bar items
        }
        if Thread.isMainThread {
            cleanupTask()
        } else {
            DispatchQueue.main.sync { cleanupTask() } // Sync if called from background
        }

        // Remove window observers if added
        // (Assuming observers might be added elsewhere, e.g., in MainWindowManager)
        // NotificationCenter.default.removeObserver(self) // Be more specific if possible

        statusBarCleanupComplete = true
        print("AppDelegate: Cleanup complete")
    }

    // Redundant cleanupStatusBar can likely be removed if performCleanup is comprehensive
    // private func cleanupStatusBar() { ... }

    // Handle reopening via Dock icon click
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        print("AppDelegate: applicationShouldHandleReopen called, hasVisibleWindows: \(flag)")
        
        // Always show the main window when app is reopened via Dock
        DispatchQueue.main.async {
            print("AppDelegate: Showing main window from applicationShouldHandleReopen")
            self.mainWindowManager.showMainWindow()
            
            // If we're in floating window mode, also show the floating window
            if self.currentMode == "floatingWindow" {
                self.floatingWindowController.show(appDelegate: self)
            }
        }
        
        // Return false to let the system also perform its standard behavior
        return false
    }
}

// MARK: - ModeSwitching Protocol (Ensure this matches definition)
protocol ModeSwitching {
    func switchMode(to newMode: String)
}


// MARK: - EnvironmentKey for AppDelegate Access
private struct AppDelegateKey: EnvironmentKey {
    static let defaultValue: AppDelegate? = nil // Default is nil
}

extension EnvironmentValues {
    var appDelegate: AppDelegate? { // Make it optional
        get { self[AppDelegateKey.self] }
        set { self[AppDelegateKey.self] = newValue }
    }
}

// MARK: - NSWindowDelegate Extension (If needed)
extension AppDelegate: NSWindowDelegate {
    // Implement delegate methods if AppDelegate needs to respond to window events
    // Example:
    // func windowWillClose(_ notification: Notification) {
    //     print("Main window closing")
    //     // Handle closing if necessary
    // }
}
