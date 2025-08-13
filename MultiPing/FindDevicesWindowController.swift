import AppKit
import SwiftUI

// Missing FindDevicesWindowController
class FindDevicesWindowController: NSObject {
    static let shared = FindDevicesWindowController()
    
    private var window: NSWindow?
    
    func show() {
        print("FindDevicesWindowController: show() called")
        
        // Try to open via the openWindow environment action
        if let delegate = NSApp.delegate as? AppDelegate {
            // Switch to menu bar mode to ensure proper window management
            delegate.switchMode(to: "menuBar")
        }
        
        // Use NSApp to try opening the window
        DispatchQueue.main.async {
            NSApp.sendAction(Selector(("openWindow:")), to: nil, from: "findDevices")
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func configureFindDevicesWindow(_ window: NSWindow) {
        print("FindDevicesWindowController: configureFindDevicesWindow called")
        self.window = window
        // Configure the window as needed
        window.title = "Find Devices"
    }
}

// Find Devices View with network scanning
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