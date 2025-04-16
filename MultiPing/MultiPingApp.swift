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
                .environmentObject(appDelegate)
                .frame(minWidth: 280, maxWidth: 320, minHeight: 500)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

// Move AppDelegate to this file to ensure it's in scope
@objc class AppDelegate: NSObject, NSApplicationDelegate, ModeSwitching, ObservableObject {

    // MARK: - Published Properties
    @Published var currentMode: String = "menuBar" // Single source of truth

    // MARK: - Controllers and Managers
    private var menuBarController = MenuBarController.shared
    var pingManager = PingManager.shared
    private var mainWindowManager = MainWindowManager.shared
    private var floatingWindowController = FloatingWindowController.shared

    // MARK: - Internal State
    var cancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>() // Store cancellables
    private var statusBarCleanupComplete = false

    // MARK: - Lifecycle
    override init() {
        super.init()
        // Observe changes to currentMode to persist it
        $currentMode
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main) // Debounce to avoid rapid writes
            .sink { mode in
                print("Saving mode to UserDefaults: \\(mode)")
                UserDefaults.standard.set(mode, forKey: "preferredInterface")
            }
            .store(in: &cancellables)
    }

    deinit {
        performCleanup()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("AppDelegate: applicationDidFinishLaunching")
        setupSignalHandling()

        // Configure the main window *before* showing it
        if let window = NSApp.windows.first { // Assume the first window is the main one
            mainWindowManager.configureMainWindow(window)
        } else {
            print("AppDelegate: Error - Main window not found during launch.")
            // Handle error? Maybe schedule a check?
        }

        // Always start in menu bar mode explicitly
        currentMode = "menuBar"
        print("AppDelegate: Initial mode set to \\(currentMode)")

        menuBarController.setup(with: pingManager)
        mainWindowManager.showMainWindow() // Now uses the stored reference

        setupDeviceUpdatesSubscription()
        startPingTimer()

        // Apply the initial mode UI state
        applyModeState(mode: currentMode)
        print("AppDelegate: Initial mode UI applied")
    }

    func applicationWillTerminate(_ notification: Notification) {
        performCleanup()
        Thread.sleep(forTimeInterval: 0.1) // Allow cleanup
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep running even if main window closes
    }

    // MARK: - Setup Methods
    private func setupSignalHandling() {
        signal(SIGTERM) { _ in
            // Use weak self or ensure proper capture semantics if needed
            if let delegate = NSApp.delegate as? AppDelegate {
                print("Received SIGTERM, performing cleanup.")
                delegate.performCleanup()
            }
            exit(0)
        }
    }

    private func setupDeviceUpdatesSubscription() {
        pingManager.$devices
            .receive(on: RunLoop.main)
            .sink { [weak self] devices in
                self?.menuBarController.updateStatusItem(with: devices)
            }
            .store(in: &cancellables) // Store cancellable
    }

    private func startPingTimer() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.pingManager.pingAll { updatedDevices in
                 // The subscription above handles the UI update
                 // Optionally log here if needed
            }
        }
        // Note: This timer doesn't need to be stored if it repeats indefinitely
        // and doesn't need explicit invalidation before app termination.
    }

    // MARK: - Mode Switching Core Logic
    func switchMode(to newMode: String) {
        guard newMode != currentMode else {
            print("AppDelegate: Mode \\(newMode) is already active.")
            return
        }
        guard ["menuBar", "floatingWindow", "cli"].contains(newMode) else {
            print("AppDelegate: Invalid mode requested: \\(newMode)")
            return
        }

        print("AppDelegate: Switching mode from \\(currentMode) to \\(newMode)")
        currentMode = newMode // Update the published property (triggers save via sink)

        // Apply the UI state for the new mode
        applyModeState(mode: newMode)
    }

    private func applyModeState(mode: String) {
        print("AppDelegate: Applying UI state for mode \\(mode)")
        // Use DispatchQueue.main.async to ensure UI updates happen on the main thread
        DispatchQueue.main.async {
            switch mode {
            case "menuBar":
                print("Applying menuBar state")
                self.floatingWindowController.hide()
                self.menuBarController.show() // Ensure menu bar is visible
                self.mainWindowManager.showMainWindow() // Ensure main window is visible

            case "floatingWindow":
                print("Applying floatingWindow state")
                self.menuBarController.hide() // Hide menu bar icons
                self.mainWindowManager.hideMainWindow() // Hide main window
                self.floatingWindowController.show(appDelegate: self) // Pass self

            case "cli":
                print("Applying cli state")
                self.floatingWindowController.hide()
                self.menuBarController.hide()
                self.mainWindowManager.hideMainWindow()
                self.launchCliScript()

            default:
                print("Applying default (menuBar) state due to unknown mode")
                self.floatingWindowController.hide()
                self.menuBarController.show()
                self.mainWindowManager.showMainWindow()
            }
            print("AppDelegate: Finished applying UI state for mode \\(mode)")
        }
    }

    // MARK: - CLI Script Launching
    private func launchCliScript() {
        print("Attempting to launch cli.py")
        guard let scriptPath = Bundle.main.path(forResource: "cli", ofType: "py") else {
            print("Error: Could not find cli.py in the app bundle.")
            DispatchQueue.main.async {
                 self.switchMode(to: "menuBar")
            }
            return
        }
        print("Found cli.py at: \(scriptPath)")

        // Get the specific python3 path (replace with user's actual path)
        let pythonPath = "/Users/jamie/.pyenv/shims/python3" // <-- REPLACE WITH ACTUAL PATH from 'which python3'

        // Construct the command using AppleScript's 'quoted form of' for safety
        // Keep '&& exit' removed for debugging
        let appleScriptSource = """
        set pyPath to quoted form of \"\(pythonPath)\"
        set scriptArg to quoted form of \"\(scriptPath)\"
        set commandToRun to pyPath & \" \" & scriptArg
        print(\"Final command for Terminal: \" & commandToRun) -- Log inside AppleScript

        tell application \"Terminal\"
            activate
            try
                do script commandToRun
            on error errMsg number errorNumber
                 log \"AppleScript Execution Error: \" & errMsg & \" (\" & errorNumber & \")\"
                 -- Optionally signal back to the app or display an error
            end try
        end tell
        """
        print("Generated AppleScript:\n\(appleScriptSource)") // Log the script source

        var errorDict: NSDictionary? = nil
        if let scriptObject = NSAppleScript(source: appleScriptSource) {
            if scriptObject.executeAndReturnError(&errorDict) != nil {
                print("AppleScript executed (check Terminal for script output/errors).")
            } else {
                print("AppleScript Execution Failed: \(errorDict ?? [:])")
                DispatchQueue.main.async {
                     self.switchMode(to: "menuBar") // Fallback on error
                 }
            }
        } else {
            print("Error: Could not create NSAppleScript object.")
             DispatchQueue.main.async {
                 self.switchMode(to: "menuBar") // Fallback on error
             }
        }
    }

    // MARK: - Actions
    @objc func openSettings() {
        print("AppDelegate: openSettings called")
        // Switch to menu bar mode first, which will show the main window
        switchMode(to: "menuBar")
        // Ensure the app is active
        DispatchQueue.main.async {
             NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Cleanup
    private func performCleanup() {
        guard !statusBarCleanupComplete else { return }
        print("AppDelegate: Performing cleanup")

        // Cancel Combine subscriptions
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        // Cancel legacy cancellable if still used
        cancellable?.cancel()
        cancellable = nil

        // Ensure UI cleanup is on main thread
        let cleanupTask = { [weak self] in
            print("AppDelegate: Cleaning up status bar")
            self?.menuBarController.cleanup() // Safely call cleanup
            // Any other UI cleanup
        }

        if Thread.isMainThread {
            cleanupTask()
        } else {
            DispatchQueue.main.sync {
                cleanupTask()
            }
        }

        // Clean up observers (ensure window reference is valid or handle nil)
        if let window = NSApp.windows.first(where: { $0.title == "Devices" }) {
             print("AppDelegate: Removing window observers")
            NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: window)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: window)
        } else {
             print("AppDelegate: Main window not found for observer removal.")
        }

        statusBarCleanupComplete = true
        print("AppDelegate: Cleanup complete")
    }

    private func cleanupStatusBar() {
        // This method seems redundant now, performCleanup handles it.
        // Kept for compatibility if called elsewhere, but recommend removing if not.
        print("AppDelegate: cleanupStatusBar called (consider removing)")
        // performCleanup() // Delegate to the main cleanup logic - REMOVED, handled by performCleanup directly
    }

     // MARK: - Deprecated/Refactored Methods (Remove)
     // func showMenuBar() { ... } - REMOVED
     // func hideMenuBar() { ... } - REMOVED
}

// Add EnvironmentKey for AppDelegate
private struct AppDelegateKey: EnvironmentKey {
    static let defaultValue: AppDelegate? = nil
}

extension EnvironmentValues {
    var appDelegate: AppDelegate? {
        get { self[AppDelegateKey.self] }
        set { self[AppDelegateKey.self] = newValue }
    }
}

// Extension for window delegate methods remains the same
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === NSApp.windows.first(where: { $0.title == "Devices" }) {
            // Remove observers
            NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: window)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: window)
        }
    }
}
