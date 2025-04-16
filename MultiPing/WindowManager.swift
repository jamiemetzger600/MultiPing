import SwiftUI
import AppKit

class MainWindowManager {
    static let shared = MainWindowManager()
    private let windowFrameKey = "MainWindowFrame"
    private weak var mainWindow: NSWindow?
    
    func configureMainWindow(_ window: NSWindow) {
        print("WindowManager: Configuring main window reference.")
        self.mainWindow = window
        window.title = "Devices"
        
        // Restore frame from UserDefaults FIRST
        if let frame = frameFromUserDefaults() {
            print("WindowManager: Restoring frame from UserDefaults: \(frame)")
            window.setFrame(frame, display: true)
        } else {
            print("WindowManager: No saved frame found, centering window.")
            window.center() // Center only if no saved frame
            // Save the initial centered frame
            saveWindowFrame(window)
        }
        
        // Configure window behavior
        window.styleMask.insert([.resizable, .titled, .closable]) // Ensure closable is present
        window.isReleasedWhenClosed = false // Important for showing again
        window.collectionBehavior = .fullScreenPrimary
        
        // Setup handlers AFTER configuring window
        setupWindowFrameHandling(window)
        print("WindowManager: Main window configured.")
    }
    
    func showMainWindow() {
        print("WindowManager: Attempting to show main window.")
        guard let window = mainWindow else {
            print("WindowManager: Error - Main window reference is nil. Cannot show.")
            return
        }
        
        print("WindowManager: Found window via stored reference.")
        // Ensure frame is restored if needed (e.g., if app was hidden)
        // But rely on configureMainWindow for initial setup
        if !window.isVisible {
            if let savedFrame = frameFromUserDefaults() {
                print("WindowManager: Restoring frame from UserDefaults before showing: \(savedFrame)")
                window.setFrame(savedFrame, display: true)
            }
        }
        
        // Make visible and bring to front
        print("WindowManager: Calling orderFront for main window.")
        window.makeKeyAndOrderFront(nil) // Bring to front and make key
        
        // Activate the application to ensure focus
        print("WindowManager: Activating application.")
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideMainWindow() {
        print("WindowManager: Attempting to hide main window.")
        guard let window = mainWindow else {
             print("WindowManager: Error - Main window reference is nil. Cannot hide.")
            return
        }
        
        print("WindowManager: Found window via stored reference.")
        // Save the frame *before* hiding
        saveWindowFrame(window)
        
        print("WindowManager: Calling orderOut for main window.")
        window.orderOut(nil)
    }
    
    // Helper to load frame
    private func frameFromUserDefaults() -> NSRect? {
        guard let dict = UserDefaults.standard.dictionary(forKey: windowFrameKey) as? [String: CGFloat],
              let x = dict["x"], let y = dict["y"], let width = dict["width"], let height = dict["height"] else {
            return nil
        }
        // Basic validation for size
        guard width > 50 && height > 50 else { return nil }
        return NSRect(x: x, y: y, width: width, height: height)
    }
    
    // Helper to save frame
    private func saveWindowFrame(_ window: NSWindow?) {
        guard let window = window else { return }
        let frame = window.frame
         // Basic validation for size before saving
        guard frame.width > 50 && frame.height > 50 else { return }
        
        let dict: [String: CGFloat] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.width,
            "height": frame.height
        ]
        print("WindowManager: Saving frame to UserDefaults: \(dict)")
        UserDefaults.standard.set(dict, forKey: windowFrameKey)
        // synchronize() might not be needed but ensures immediate write
        // UserDefaults.standard.synchronize()
    }
    
    private func setupWindowFrameHandling(_ window: NSWindow) {
         print("WindowManager: Setting up frame handling for main window.")
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: window,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            print("WindowManager: Detected didResizeNotification.")
            self?.saveWindowFrame(window)
        }
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak self] notification in
             guard let window = notification.object as? NSWindow else { return }
             print("WindowManager: Detected didMoveNotification.")
            self?.saveWindowFrame(window)
        }
        
         // Also save when window is about to close (if user closes it)
         NotificationCenter.default.addObserver(
             forName: NSWindow.willCloseNotification,
             object: window,
             queue: .main
         ) { [weak self] notification in
             guard let window = notification.object as? NSWindow else { return }
             print("WindowManager: Detected willCloseNotification.")
             self?.saveWindowFrame(window)
         }
    }
} 
