import SwiftUI
import AppKit

class MainWindowManager: NSObject, NSWindowDelegate {
    static let shared = MainWindowManager()
    private let windowFrameKey = "MainWindowFrame"
    private weak var mainWindow: NSWindow?
    private var isWindowClosed = false
    
    override init() {
        super.init()
        // Register for app termination to save window frame one last time
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func applicationWillTerminate(_ notification: Notification) {
        if let window = mainWindow {
            saveWindowFrame(window)
        }
    }
    
    func configureMainWindow(_ window: NSWindow) {
        print("WindowManager: Configuring main window reference.")
        self.mainWindow = window
        window.title = "MultiPing - Devices"
        
        // Set delegate to self to catch window close events
        window.delegate = self
        
        // Use autosave name for NSWindow's built-in frame persistence
        window.setFrameAutosaveName("mainWindow")
        
        // Try to restore frame from our custom UserDefaults first (for more control)
        if let frame = frameFromUserDefaults() {
            print("WindowManager: Restoring frame from UserDefaults: \(frame)")
            window.setFrame(frame, display: true)
        } else {
            print("WindowManager: No saved frame found, using default size.")
            // Set a good default size if none saved
            let screenSize = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
            let defaultSize = NSSize(width: 500, height: 600)
            let defaultOrigin = NSPoint(
                x: screenSize.midX - defaultSize.width/2,
                y: screenSize.midY - defaultSize.height/2
            )
            let defaultFrame = NSRect(origin: defaultOrigin, size: defaultSize)
            window.setFrame(defaultFrame, display: true)
            
            // Save the initial default frame
            saveWindowFrame(window)
        }
        
        // Configure window behavior
        window.styleMask.insert([.resizable, .titled, .closable, .miniaturizable]) 
        window.isReleasedWhenClosed = false // Critical for showing window again after close
        window.collectionBehavior = .fullScreenPrimary
        
        // Setup handlers for additional frame persistence control
        setupWindowFrameHandling(window)
        
        // Reset closed state
        isWindowClosed = false
        
        print("WindowManager: Main window configured.")
    }
    
    func ensureMainWindow(appDelegate: AppDelegate) {
        // If we already have a configured window, just show it
        if let window = mainWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Try to find existing window first
        if mainWindow == nil, let existing = findMainWindow() {
            configureMainWindow(existing)
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create a new window hosting the DeviceListView as a last resort
        let contentView = DeviceListView()
            .environmentObject(appDelegate)
        
        // Try to restore saved frame first, otherwise use default size
        let frame: NSRect
        if let savedFrame = frameFromUserDefaults() {
            frame = savedFrame
            print("WindowManager: Using saved frame for new main window: \(frame)")
        } else {
            let screenSize = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
            let defaultSize = NSSize(width: 500, height: 600)
            let defaultOrigin = NSPoint(
                x: screenSize.midX - defaultSize.width/2,
                y: screenSize.midY - defaultSize.height/2
            )
            frame = NSRect(origin: defaultOrigin, size: defaultSize)
            print("WindowManager: Using default frame for new main window: \(frame)")
        }
        
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MultiPing - Devices"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: contentView)
        configureMainWindow(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showMainWindow() {
        print("WindowManager: Attempting to show main window.")
        
        // Debug window properties
        print("WindowManager: Main window reference exists: \(mainWindow != nil)")
        print("WindowManager: isWindowClosed flag: \(isWindowClosed)")
        print("WindowManager: All app windows: \(NSApp.windows.count)")
        NSApp.windows.forEach { window in
            print("WindowManager: Window title: '\(window.title)', visible: \(window.isVisible), miniaturized: \(window.isMiniaturized)")
        }
        
        // Simplified window finding logic
        if mainWindow == nil || isWindowClosed {
            print("WindowManager: Window is nil or closed. Finding main window.")
            
            // Look for the main window by title or content
            if let window = findMainWindow() {
                print("WindowManager: Found main window with title: '\(window.title)'")
                mainWindow = window
                window.title = "MultiPing - Devices" // Standardize the title
                isWindowClosed = false
            } else {
                print("WindowManager: Cannot find main window. Cannot show.")
                return
            }
        }
        
        guard let window = mainWindow else {
            print("WindowManager: Error - Main window reference is nil. Cannot show.")
            return
        }
        
        // Restore saved frame if window is not visible
        if !window.isVisible {
            if let savedFrame = frameFromUserDefaults() {
                print("WindowManager: Restoring frame from UserDefaults before showing: \(savedFrame)")
                window.setFrame(savedFrame, display: true)
            }
        }
        
        // Ensure we're not already showing
        print("WindowManager: Current window state - isVisible: \(window.isVisible), isMiniaturized: \(window.isMiniaturized)")
        
        // Make visible and bring to front
        print("WindowManager: Calling orderFront for main window.")
        window.makeKeyAndOrderFront(nil)
        
        // Ensure window is deminiaturized if it was minimized
        if window.isMiniaturized {
            print("WindowManager: Deminiaturizing window")
            window.deminiaturize(nil)
        }
        
        // Activate the application to ensure focus
        print("WindowManager: Activating application.")
        NSApp.activate(ignoringOtherApps: true)
        
        isWindowClosed = false
    }
    
    // Simplified method to find the main window
    private func findMainWindow() -> NSWindow? {
        // First, try to find by exact title
        if let window = NSApp.windows.first(where: { 
            $0.title == "MultiPing - Devices" || 
            $0.title == "Devices" ||
            $0.title == "MultiPing"
        }) {
            return window
        }
        
        // If no exact match, look for any window that might be the main window
        // (not a panel, not the find devices window)
        if let window = NSApp.windows.first(where: { 
            !$0.isMiniaturized && 
            $0.styleMask.contains(.titled) &&
            $0.title != "Find Devices" &&
            $0.contentView != nil
        }) {
            return window
        }
        
        return nil
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
        
        // Basic validation for size and position
        guard width >= 300 && height >= 300 else { return nil }
        
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
    
    // Helper to save frame
    private func saveWindowFrame(_ window: NSWindow?) {
        guard let window = window else { return }
        let frame = window.frame
        
        // Basic validation for size before saving
        guard frame.width >= 300 && frame.height >= 300 else { return }
        
        let dict: [String: CGFloat] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.width,
            "height": frame.height
        ]
        print("WindowManager: Saving frame to UserDefaults: \(dict)")
        UserDefaults.standard.set(dict, forKey: windowFrameKey)
        UserDefaults.standard.synchronize() // Force immediate write
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
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        print("WindowManager: Window is closing.")
        if let window = notification.object as? NSWindow, window === mainWindow {
            saveWindowFrame(window)
            isWindowClosed = true
        }
    }
    
    func windowDidResize(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === mainWindow {
            saveWindowFrame(window)
        }
    }
    
    func windowDidMove(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === mainWindow {
            saveWindowFrame(window)
        }
    }
} 
