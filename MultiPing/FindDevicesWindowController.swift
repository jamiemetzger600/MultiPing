import AppKit
import SwiftUI

class FindDevicesWindowController: NSObject {
    static let shared = FindDevicesWindowController()
    
    private var window: NSWindow?
    private var appDelegate: AppDelegate?
    private var isCreatingWindow = false // Prevent multiple window creation
    
    func show(appDelegate: AppDelegate) {
        print("FindDevicesWindowController: show(appDelegate:) called")
        
        // Store the AppDelegate reference
        self.appDelegate = appDelegate
        
        // Prevent multiple simultaneous window creation attempts
        guard !isCreatingWindow else {
            print("FindDevicesWindowController: Window creation already in progress, skipping")
            return
        }
        
        // Use NSApp to try opening the window with a more reliable approach
        DispatchQueue.main.async {
            // First try the standard openWindow action
            print("FindDevicesWindowController: Attempting to open window via openWindow action")
            NSApp.sendAction(Selector(("openWindow:")), to: nil, from: "findDevices")
            
            // Wait a bit for the SwiftUI window to appear, then check
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Check if the SwiftUI window appeared
                if let findDevicesWindow = NSApp.windows.first(where: { 
                    $0.title == "Find Devices" || 
                    $0.title.contains("findDevices") ||
                    $0.identifier?.rawValue == "findDevices"
                }) {
                    print("FindDevicesWindowController: Found existing Find Devices window, showing it")
                    findDevicesWindow.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                } else {
                    print("FindDevicesWindowController: Could not find Find Devices window, using our persistent window")
                    // Use our persistent window instead of creating new ones
                    self.showPersistentWindow()
                }
            }
        }
    }
    
    private func showPersistentWindow() {
        print("FindDevicesWindowController: Showing persistent window")
        
        // If we don't have a window yet, create it once
        if window == nil {
            print("FindDevicesWindowController: Creating persistent window for first time")
            createPersistentWindow()
        }
        
        // Show the existing window
        if let existingWindow = window {
            print("FindDevicesWindowController: Showing existing persistent window")
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func createPersistentWindow() {
        print("FindDevicesWindowController: Creating persistent window")
        
        // Set flag to prevent multiple creation attempts
        isCreatingWindow = true
        
        // Create a new window
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "Find Devices"
        newWindow.center()
        
        // Create the full SwiftUI FindDevicesView with AppDelegate
        if let appDelegate = self.appDelegate {
            let hostingView = NSHostingView(rootView: FindDevicesView().environmentObject(appDelegate))
            newWindow.contentView = hostingView
        } else {
            // Fallback to simple view if no AppDelegate
            let contentView = createSimpleFindDevicesView()
            newWindow.contentView = contentView
        }
        
        // Store the window reference
        self.window = newWindow
        
        print("FindDevicesWindowController: Persistent window created successfully")
        
        // Reset flag
        isCreatingWindow = false
    }
    
    private func createSimpleFindDevicesView() -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // Create title label
        let titleLabel = NSTextField(labelWithString: "Find Network Devices")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Create scan button
        let scanButton = NSButton(title: "Start Network Scan", target: self, action: #selector(startNetworkScan))
        scanButton.translatesAutoresizingMaskIntoConstraints = false
        scanButton.bezelStyle = .rounded
        view.addSubview(scanButton)
        
        // Create status label
        let statusLabel = NSTextField(labelWithString: "Click 'Start Network Scan' to discover devices on your network")
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = NSColor.secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        // Create close button
        let closeButton = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .rounded
        view.addSubview(closeButton)
        
        // Set up constraints with safer values
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            scanButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            scanButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scanButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            
            statusLabel.topAnchor.constraint(equalTo: scanButton.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            closeButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
        
        return view
    }
    
    @objc private func startNetworkScan() {
        print("FindDevicesWindowController: Network scan requested")
        // For now, just show a simple message
        let alert = NSAlert()
        alert.messageText = "Network Scan"
        alert.informativeText = "Network scanning functionality would be implemented here. This is a simplified fallback window to avoid crashes."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func closeWindow() {
        print("FindDevicesWindowController: Hiding persistent window")
        // Just hide the window instead of closing it to maintain persistence
        window?.orderOut(nil)
        print("FindDevicesWindowController: Window hidden")
    }
    
    func configureFindDevicesWindow(_ window: NSWindow) {
        print("FindDevicesWindowController: configureFindDevicesWindow called")
        self.window = window
        // Configure the window as needed
        window.title = "Find Devices"
        window.identifier = NSUserInterfaceItemIdentifier("findDevices")
    }
}

// Add NSWindowDelegate conformance to handle window lifecycle
extension FindDevicesWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        print("FindDevicesWindowController: Window will close")
        if let closingWindow = notification.object as? NSWindow, closingWindow === window {
            print("FindDevicesWindowController: Our window is closing, cleaning up")
            // Just reset the flag, don't do complex cleanup
            isCreatingWindow = false
        }
    }
}

// Original FindDevicesView for the SwiftUI app (requires AppDelegate)
struct FindDevicesView: View {
    @StateObject private var networkScanner = NetworkScanner()
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var selectedDevices = Set<UUID>()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Find Network Devices")
                    .font(.title2)
                Spacer()
                Button("Close") {
                    NSApp.keyWindow?.close()
                }
            }
            
            HStack {
                Button(networkScanner.isScanning ? "Stop Scan" : "Start Scan") {
                    if networkScanner.isScanning {
                        networkScanner.stopScanning()
                    } else {
                        networkScanner.startScanning()
                    }
                }
                .disabled(networkScanner.isScanning)
                
                if networkScanner.isScanning {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Scanning network...")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !selectedDevices.isEmpty {
                    Button("Add Selected (\(selectedDevices.count))") {
                        addSelectedDevices()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            Divider()
            
            if networkScanner.discoveredDevices.isEmpty && !networkScanner.isScanning {
                VStack {
                    Image(systemName: "network")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No devices found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Click 'Start Scan' to discover devices on your network")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(networkScanner.discoveredDevices, id: \.id, selection: $selectedDevices) { device in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(device.hostname.isEmpty ? "Unknown Device" : device.hostname)
                                .font(.headline)
                            Text(device.ipAddress)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Circle()
                            .fill(device.isReachable ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .frame(minWidth: 650, minHeight: 500)
    }
    
    private func addSelectedDevices() {
        let devicesToAdd = networkScanner.discoveredDevices.filter { selectedDevices.contains($0.id) }
        for device in devicesToAdd {
            let newDevice = Device(
                name: device.hostname.isEmpty ? device.ipAddress : device.hostname,
                ipAddress: device.ipAddress
            )
            _ = PingManager.shared.addDevice(newDevice)
        }
        selectedDevices.removeAll()
        NSApp.keyWindow?.close()
    }
}

// Standalone version of FindDevicesView that doesn't require AppDelegate
struct StandaloneFindDevicesView: View {
    @StateObject private var networkScanner = NetworkScanner()
    @State private var selectedDevices = Set<UUID>()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Find Network Devices")
                    .font(.title2)
                Spacer()
                Button("Close") {
                    NSApp.keyWindow?.close()
                }
            }
            
            HStack {
                Button(networkScanner.isScanning ? "Stop Scan" : "Start Scan") {
                    if networkScanner.isScanning {
                        networkScanner.stopScanning()
                    } else {
                        networkScanner.startScanning()
                    }
                }
                .disabled(networkScanner.isScanning)
                
                if networkScanner.isScanning {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Scanning network...")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !selectedDevices.isEmpty {
                    Button("Add Selected (\(selectedDevices.count))") {
                        addSelectedDevices()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            Divider()
            
            if networkScanner.discoveredDevices.isEmpty && !networkScanner.isScanning {
                VStack {
                    Image(systemName: "network")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No devices found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Click 'Start Scan' to discover devices on your network")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(networkScanner.discoveredDevices, id: \.id, selection: $selectedDevices) { device in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(device.hostname.isEmpty ? "Unknown Device" : device.hostname)
                                .font(.headline)
                            Text(device.ipAddress)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Circle()
                            .fill(device.isReachable ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .frame(minWidth: 650, minHeight: 500)
    }
    
    private func addSelectedDevices() {
        let devicesToAdd = networkScanner.discoveredDevices.filter { selectedDevices.contains($0.id) }
        for device in devicesToAdd {
            let newDevice = Device(
                name: device.hostname.isEmpty ? device.ipAddress : device.hostname,
                ipAddress: device.ipAddress
            )
            _ = PingManager.shared.addDevice(newDevice)
        }
        selectedDevices.removeAll()
        NSApp.keyWindow?.close()
    }
}