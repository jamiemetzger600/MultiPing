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
                    // Use a more robust approach to find the window
                    var attempts = 0
                    func configureWindow() {
                        if let window = NSApp.windows.first(where: { 
                            $0.title == "Find Devices" || 
                            $0.title.contains("findDevices") ||
                            $0.identifier?.rawValue == "findDevices"
                        }) {
                            FindDevicesWindowController.shared.configureFindDevicesWindow(window)
                        } else if attempts < 5 {
                            attempts += 1
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                                configureWindow()
                            }
                        }
                    }
                    configureWindow()
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
        menuBarController.setup(with: pingManager, appDelegate: self) // Pass self as AppDelegate
        
        // Ensure floating window is hidden at launch
        floatingWindowController.hide()
        
        // Show the main window immediately
        mainWindowManager.showMainWindow()
        
        // Apply menuBar state at launch
        applyModeState(mode: "menuBar")
        print("AppDelegate: Initial mode UI applied")
        
        // Restore saved preference after a brief delay to ensure UI is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let savedMode = UserDefaults.standard.string(forKey: "preferredInterface") ?? "menuBar"
            if savedMode != "menuBar" {
                self.switchMode(to: savedMode)
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
        
        // Update mode immediately to prevent race conditions
        currentMode = newMode
        
        // Apply the new mode state synchronously
        applyModeState(mode: newMode)
        
        print("====================================================================")
    }

    private func applyModeState(mode: String) {
        print("AppDelegate: Applying UI state for mode \(mode)")
        
        // Ensure UI updates on main thread
        DispatchQueue.main.async {
            switch mode {
            case "menuBar":
                print("Applying menuBar state:")
                // Hide floating window first
                self.floatingWindowController.hide()
                
                // Setup and show menu bar
                self.menuBarController.setup(with: self.pingManager, appDelegate: self)
                self.menuBarController.show()
                
                // Show main window
                self.mainWindowManager.showMainWindow()
                NSApp.activate(ignoringOtherApps: true)
                
            case "floatingWindow":
                print("Applying floatingWindow state:")
                // Hide main window and menu bar
                self.mainWindowManager.hideMainWindow()
                self.menuBarController.hide()
                
                // Show floating window
                self.floatingWindowController.show(appDelegate: self)
                
            case "cli":
                print("Applying cli state:")
                // Hide all UI
                self.floatingWindowController.hide()
                self.menuBarController.hide()
                self.mainWindowManager.hideMainWindow()
                self.launchCliScript()
                
            default:
                print("Applying default (menuBar) state due to unknown mode: \(mode)")
                self.floatingWindowController.hide()
                self.menuBarController.setup(with: self.pingManager, appDelegate: self)
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

        // Find Python path dynamically instead of hardcoding
        let pythonPath = findPythonPath()

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
        // Show main window directly - settings are in the main interface
        switchMode(to: "menuBar")
        mainWindowManager.showMainWindow()
        NSApp.activate(ignoringOtherApps: true)
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
    
    // MARK: - Helper Methods
    private func findPythonPath() -> String {
        // Try to find python3 in common paths
        let commonPaths = [
            "/usr/bin/python3",
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/bin/python",
            "/usr/local/bin/python"
        ]
        
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                print("Found Python at: \(path)")
                return path
            }
        }
        
        // Try to use 'which python3' command as fallback
        let task = Process()
        task.launchPath = "/usr/bin/which"
        task.arguments = ["python3"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !output.isEmpty {
                    print("Found Python via which: \(output)")
                    return output
                }
            }
        } catch {
            print("Error running 'which python3': \(error)")
        }
        
        // Fallback to default system python
        print("Using fallback Python path: /usr/bin/python3")
        return "/usr/bin/python3"
    }
}

// ModeSwitching protocol is defined in Protocols.swift


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
