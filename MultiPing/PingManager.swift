import Foundation
import Combine // Import Combine for AnyCancellable

class PingManager: ObservableObject {
    static let shared = PingManager()

    @Published var devices: [Device] = [] {
        didSet {
            saveDevices()
            // Post notification when devices change (including order changes)
            NotificationCenter.default.post(name: .deviceListChanged, object: nil)
        }
    }

    // Published property for the interval
    @Published var pingInterval: Double = 3.0 // Default to 3 seconds

    private let fileURL: URL = {
        guard let documents = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Unable to access application support directory")
        }
        let dir = documents.appendingPathComponent("MultiPing")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("devices.json")
    }()

    // Store the timer internally
    private var pingTimer: Timer?
    private var cancellables = Set<AnyCancellable>() // To observe interval changes

    private init() {
        // Force reset ping interval to 3 seconds
        pingInterval = 3.0
        UserDefaults.standard.set(pingInterval, forKey: "pingInterval")
        print("PingManager: Force setting default ping interval to 3 seconds")
        
        loadDevices()
        loadPingInterval() // Load saved interval (which is now 3s)
        setupIntervalObserver() // Observe changes to interval property
        startPingTimer()   // Start the timer with the loaded interval
        print("PingManager initialized. Interval: \(pingInterval)")
    }

    // --- New Timer Management ---

    func startPingTimer() {
        print("PingManager: Starting timer with interval \(pingInterval) seconds.")
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
             print("PingManager: Timer fired. Pinging all.")
            self?.pingAll()
        }
        pingTimer?.fire()
    }

    func stopPingTimer() {
        print("PingManager: Stopping timer.")
        pingTimer?.invalidate()
        pingTimer = nil
    }

    func cleanup() {
        stopPingTimer()
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
         print("PingManager: Cleanup complete.")
    }
    
    private func setupIntervalObserver() {
        $pingInterval
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main) // Add debounce
            .sink { [weak self] newInterval in
                guard let self = self, newInterval > 0 else { return }
                 print("PingManager: Interval changed to \(newInterval). Restarting timer.")
                self.startPingTimer()
            }
            .store(in: &cancellables)
    }


    // --- Interval Persistence ---

    private func loadPingInterval() {
        let savedInterval = UserDefaults.standard.double(forKey: "pingInterval")
        if savedInterval > 0 { 
            pingInterval = savedInterval
             print("PingManager: Loaded interval from UserDefaults: \(pingInterval)")
        } else {
            pingInterval = 3.0
            UserDefaults.standard.set(pingInterval, forKey: "pingInterval")
             print("PingManager: No valid interval in UserDefaults, using default: \(pingInterval)")
        }
    }

    func updatePingInterval(_ newInterval: Double) {
        // Allow intervals as low as 0.01 seconds
        let validatedInterval = max(0.01, newInterval)
        print("PingManager: Updating interval to \(validatedInterval)")
        pingInterval = validatedInterval
        UserDefaults.standard.set(pingInterval, forKey: "pingInterval")
        print("PingManager: Saved interval \(pingInterval) to UserDefaults.")
    }

    // --- Existing Methods ---

    func addDevice(_ device: Device) -> Bool {
        // Validate IP address first
        if !isValidIPAddress(device.ipAddress) {
            print("PingManager: Invalid IP address format: \(device.ipAddress)")
            return false
        }
        
        // Check if a device with the same IP already exists to avoid duplicates
        if !devices.contains(where: { $0.ipAddress == device.ipAddress }) {
            print("PingManager: Adding device \(device.name) - \(device.ipAddress)")
            devices.append(device)
            pingDeviceImmediately(device) // Ping the new device right away
            NotificationCenter.default.post(name: NSNotification.Name("DevicesDidChange"), object: nil)
            return true // <-- Return true because device was added
        } else {
            print("PingManager: Device with IP \(device.ipAddress) already exists. Skipping add.")
            // Optionally, provide feedback to the user here
            return false // <-- Return false because device was not added
        }
    }

    // IP validation function - shared with UI validation
    func isValidIPAddress(_ ip: String) -> Bool {
        // Check for correct total length first (prevents validation of absurdly long strings)
        guard ip.count <= 253 else { return false }
        
        // Basic IPv4 validation regex - strict pattern requiring exactly 4 parts
        let ipv4Pattern = #"^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"#
        
        // Allow hostnames too (basic validation)
        let hostnamePattern = #"^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$"#
        
        // For IPv4, do additional validation to catch cases like "1289.345.90.289"
        if ip.contains(".") && !ip.contains(":") {
            // Split by dots and validate each component individually
            let components = ip.split(separator: ".")
            
            // Must have exactly 4 components
            if components.count != 4 {
                return false
            }
            
            // Each component must be a valid number between 0-255
            for component in components {
                if let value = Int(component) {
                    if value < 0 || value > 255 {
                        return false
                    }
                } else {
                    return false // Not a number
                }
            }
        }
        
        // Run the regex validation as an additional check
        return ip.range(of: ipv4Pattern, options: .regularExpression) != nil || 
               ip.range(of: hostnamePattern, options: .regularExpression) != nil
    }

    func loadDevices() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        devices = (try? JSONDecoder().decode([Device].self, from: data)) ?? []
    }

    func saveDevices() {
        try? JSONEncoder().encode(devices).write(to: fileURL)
    }

    func updateDevice(updatedDevice: Device) {
         if let index = devices.firstIndex(where: { $0.id == updatedDevice.id }) {
             print("PingManager: Updating device ID \(updatedDevice.id) at index \(index)")
             let oldIpAddress = devices[index].ipAddress
             devices[index] = updatedDevice
             if oldIpAddress != updatedDevice.ipAddress {
                  print("PingManager: IP address changed for \(updatedDevice.name). Pinging immediately.")
                 pingDeviceImmediately(updatedDevice)
             }
             NotificationCenter.default.post(name: NSNotification.Name("DevicesDidChange"), object: nil)
         } else {
              print("PingManager: Error - Could not find device with ID \(updatedDevice.id) to update.")
         }
    }

    func pingDeviceImmediately(_ device: Device) {
         DispatchQueue.global(qos: .background).async { [weak self] in
             guard let self = self else { return }
             let pingResult = self.ping(ip: device.ipAddress)
             DispatchQueue.main.async { [weak self] in
                 guard let self = self else { return }
                 // Use a more robust approach to find and update the device
                 // Make a copy of the devices array to avoid race conditions
                 let currentDevices = self.devices
                 
                 // Ensure we don't access out of bounds
                 guard !currentDevices.isEmpty else { return }
                 
                 for i in 0..<currentDevices.count {
                     // Double-check bounds before accessing
                     guard i < self.devices.count else { continue }
                     if self.devices[i].id == device.id {
                         // Update device with ping results
                         self.devices[i].isReachable = pingResult.success
                         self.devices[i].lastLatency = pingResult.latency
                         self.devices[i].lastPacketLoss = pingResult.packetLoss
                         self.devices[i].lastPingTime = Date()
                         break
                     }
                 }
             }
         }
    }

    func pingAll(completion: (([Device]) -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            let dispatchGroup = DispatchGroup()
            var updatedDevices = self.devices
            let queue = DispatchQueue(label: "com.multiping.pingqueue", attributes: .concurrent)

            for index in updatedDevices.indices {
                dispatchGroup.enter()
                queue.async {
                    let pingResult = self.ping(ip: updatedDevices[index].ipAddress)
                    DispatchQueue.main.async {
                        if updatedDevices.indices.contains(index) {
                            updatedDevices[index].isReachable = pingResult.success
                            updatedDevices[index].lastLatency = pingResult.latency
                            updatedDevices[index].lastPacketLoss = pingResult.packetLoss
                            updatedDevices[index].lastPingTime = Date()
                        }
                        dispatchGroup.leave()
                    }
                }
            }

            dispatchGroup.wait()

            DispatchQueue.main.async {
                let hasChanges = zip(self.devices, updatedDevices).contains { 
                    $0.isReachable != $1.isReachable || 
                    $0.lastLatency != $1.lastLatency || 
                    $0.lastPacketLoss != $1.lastPacketLoss 
                }
                if hasChanges {
                    for i in self.devices.indices {
                        self.devices[i].isReachable = updatedDevices[i].isReachable
                        self.devices[i].lastLatency = updatedDevices[i].lastLatency
                        self.devices[i].lastPacketLoss = updatedDevices[i].lastPacketLoss
                        self.devices[i].lastPingTime = updatedDevices[i].lastPingTime
                    }
                }
                completion?(updatedDevices)
            }
        }
    }

    private func ping(ip: String) -> (success: Bool, latency: Double?, packetLoss: Double?) {
         let possiblePaths = ["/sbin/ping", "/usr/bin/ping"]
         guard let pingPath = possiblePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
             print("Ping binary not found on this system.")
             return (false, nil, nil)
         }

         let task = Process()
         task.launchPath = pingPath
         
         // Use a minimum timeout of 1 second for ping command, but respect the actual interval for timer
         // macOS ping needs timeout in whole seconds, so we need to use at least 1
         let timeoutValue = max(1, Int(ceil(pingInterval)))
         let timeoutString = String(timeoutValue)
         
         task.arguments = ["-c", "1", "-W", timeoutString, ip]

         let pipe = Pipe()
         task.standardOutput = pipe
         task.standardError = pipe

         do {
             try task.run()
             task.waitUntilExit()
             
             let success = task.terminationStatus == 0
             
            // Parse ping output for latency and packet loss
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let latency = parseLatency(from: output)
            let packetLoss = parsePacketLoss(from: output)
            
            return (success, latency, packetLoss)
         } catch {
             print("Failed to ping \(ip): \(error)")
             return (false, nil, nil)
         }
    }
    
    /// Parse latency from ping output
    private func parseLatency(from output: String) -> Double? {
        // Look for patterns in macOS ping output
        // Format: "round-trip min/avg/max/stddev = 32.804/32.804/32.804/0.000 ms"
        let patterns = [
            "round-trip min/avg/max/stddev = ([0-9.]+)/[0-9.]+/[0-9.]+/[0-9.]+ ms",
            "time=([0-9.]+) ms",
            "time<([0-9.]+) ms"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
               let range = Range(match.range(at: 1), in: output) {
                let latencyString = String(output[range])
                if let latency = Double(latencyString) {
                    return latency
                }
            }
        }
        
        return nil
    }
    
    /// Parse packet loss from ping output
    private func parsePacketLoss(from output: String) -> Double? {
        // Look for patterns like "0.0% packet loss" or "100% packet loss"
        let pattern = "([0-9.]+)% packet loss"
        
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
           let range = Range(match.range(at: 1), in: output) {
            let packetLossString = String(output[range])
            if let packetLoss = Double(packetLossString) {
                return packetLoss
            }
        }
        
        return nil
    }
}

// Add notification name for device list changes
extension Notification.Name {
    static let deviceListChanged = Notification.Name("deviceListChanged")
}
