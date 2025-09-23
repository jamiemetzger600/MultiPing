import Cocoa
import SwiftUI

// Ensure all necessary types are available
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Window Controller

class FindDevicesWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Find Network Devices"
        window.center()
        window.setFrameAutosaveName("FindDevicesWindow")
        
        self.init(window: window)
        
        // Set up SwiftUI content
        let contentView = EnhancedNetworkScannerView()
        window.contentView = NSHostingView(rootView: contentView)
        window.delegate = self
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        window?.makeKeyAndOrderFront(nil)
    }
}

extension FindDevicesWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        print("FindDevicesWindowController: Window will close")
        window = nil
    }
}

