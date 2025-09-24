import Foundation
import Combine

/// Live data bridge between the main MultiPing app and CLI terminal
/// Provides real-time device data updates similar to how top/htop works
class CLIDataBridge: ObservableObject {
    static let shared = CLIDataBridge()
    
    // Published properties for live data
    @Published var devices: [Device] = []
    @Published var isMonitoring: Bool = false
    @Published var lastUpdate: Date = Date()
    @Published var pingInterval: Double = 3.0
    
    // Statistics
    @Published var totalDevices: Int = 0
    @Published var onlineDevices: Int = 0
    @Published var offlineDevices: Int = 0
    
    // Display configuration
    @Published var displayMode: String = "detailed"
    
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    
    private init() {
        setupDataBridge()
    }
    
    /// Setup the data bridge to receive live updates from PingManager
    private func setupDataBridge() {
        // Subscribe to PingManager device updates
        PingManager.shared.$devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.updateDevices(devices)
            }
            .store(in: &cancellables)
        
        // Subscribe to PingManager monitoring status
        PingManager.shared.$pingInterval
            .receive(on: DispatchQueue.main)
            .sink { [weak self] interval in
                self?.pingInterval = interval
            }
            .store(in: &cancellables)
        
        // Start update timer for statistics
        startUpdateTimer()
    }
    
    /// Update device data and calculate statistics
    private func updateDevices(_ newDevices: [Device]) {
        // Prevent recursive updates
        guard !newDevices.isEmpty || !devices.isEmpty else { return }
        
        devices = newDevices
        totalDevices = newDevices.count
        onlineDevices = newDevices.filter { $0.isReachable }.count
        offlineDevices = newDevices.filter { !$0.isReachable }.count
        lastUpdate = Date()
        
        // Notify CLI terminal of data update
        NotificationCenter.default.post(
            name: Notification.Name("cliDataUpdated"),
            object: nil,
            userInfo: ["devices": newDevices]
        )
    }
    
    /// Start timer for periodic updates
    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.lastUpdate = Date()
        }
    }
    
    /// Get formatted device data for CLI display with enhanced metrics
    func getFormattedDeviceData() -> String {
        switch displayMode {
        case "simple":
            return getSimpleDisplay()
        case "compact":
            return getCompactDisplay()
        case "live":
            return getLiveDisplay()
        default: // "detailed"
            return getDetailedDisplay()
        }
    }
    
    /// Simple display mode - summary only
    private func getSimpleDisplay() -> String {
        var output = ""
        
        guard !devices.isEmpty else {
            return "No devices to monitor\n"
        }
        
        let timestamp = DateFormatter.localizedString(from: lastUpdate, dateStyle: .none, timeStyle: .medium)
        let timePrefix = "[\(timestamp)] "
        
        output += "\(timePrefix)MultiPing Summary: \(onlineDevices) UP, \(offlineDevices) DOWN\n"
        
        // Show only first 5 devices
        let devicesToShow = Array(devices.prefix(5))
        for device in devicesToShow {
            let status = device.isReachable ? "🟢" : "🔴"
            output += "  \(status) \(device.name) (\(device.ipAddress))\n"
        }
        
        if devices.count > 5 {
            output += "  ... and \(devices.count - 5) more devices\n"
        }
        
        return output
    }
    
    /// Compact display mode - ultra-compact single line
    private func getCompactDisplay() -> String {
        guard !devices.isEmpty else {
            return "No devices to monitor\n"
        }
        
        let timestamp = DateFormatter.localizedString(from: lastUpdate, dateStyle: .none, timeStyle: .medium)
        let timePrefix = "[\(timestamp)] "
        
        var line = "\(timePrefix)\(onlineDevices)✓ \(offlineDevices)✗"
        
        // Add first few device statuses
        let devicesToShow = Array(devices.prefix(3))
        for device in devicesToShow {
            let status = device.isReachable ? "✓" : "✗"
            let shortName = device.name.count > 8 ? String(device.name.prefix(5)) + "..." : device.name
            line += " \(shortName):\(status)"
        }
        
        return line + "\n"
    }
    
    /// Live display mode - real-time updates
    private func getLiveDisplay() -> String {
        var output = ""
        
        guard !devices.isEmpty else {
            return "No devices to monitor\n"
        }
        
        let timestamp = DateFormatter.localizedString(from: lastUpdate, dateStyle: .none, timeStyle: .medium)
        output += "MultiPing Live Monitor - Last Update: \(timestamp)\n"
        output += "=" + String(repeating: "=", count: 80) + "\n"
        output += "Total: \(totalDevices) | Online: \(onlineDevices) | Offline: \(offlineDevices) | Interval: \(pingInterval)s\n"
        output += "-" + String(repeating: "-", count: 80) + "\n"
        
        // Enhanced device table header with technical metrics
        let nameHeader = "NAME".padding(toLength: 20, withPad: " ", startingAt: 0)
        let ipHeader = "IP ADDRESS".padding(toLength: 18, withPad: " ", startingAt: 0)
        let statusHeader = "STATUS".padding(toLength: 8, withPad: " ", startingAt: 0)
        let latencyHeader = "LATENCY".padding(toLength: 10, withPad: " ", startingAt: 0)
        let packetLossHeader = "PACKET LOSS".padding(toLength: 12, withPad: " ", startingAt: 0)
        let noteHeader = "NOTE".padding(toLength: 15, withPad: " ", startingAt: 0)
        output += "\(nameHeader) \(ipHeader) \(statusHeader) \(latencyHeader) \(packetLossHeader) \(noteHeader)\n"
        output += "-" + String(repeating: "-", count: 80) + "\n"
        
        // Device rows with enhanced metrics
        for device in devices {
            let status = device.isReachable ? "🟢 UP" : "🔴 DOWN"
            let note = device.note?.isEmpty == false ? device.note! : "-"
            let truncatedNote = note.count > 14 ? String(note.prefix(11)) + "..." : note
            
            // Enhanced metrics from PingManager
            let latency: String
            let packetLoss: String
            
            if let deviceLatency = device.lastLatency {
                if deviceLatency < 1 {
                    latency = "<1 ms"
                } else {
                    latency = String(format: "%.1f ms", deviceLatency)
                }
            } else {
                latency = "N/A"
            }
            
            if let devicePacketLoss = device.lastPacketLoss {
                packetLoss = String(format: "%.1f%%", devicePacketLoss)
            } else {
                packetLoss = "N/A"
            }
            
            let name = device.name.padding(toLength: 20, withPad: " ", startingAt: 0)
            let ip = device.ipAddress.padding(toLength: 18, withPad: " ", startingAt: 0)
            let statusPadded = status.padding(toLength: 8, withPad: " ", startingAt: 0)
            let latencyPadded = latency.padding(toLength: 10, withPad: " ", startingAt: 0)
            let packetLossPadded = packetLoss.padding(toLength: 12, withPad: " ", startingAt: 0)
            let notePadded = truncatedNote.padding(toLength: 15, withPad: " ", startingAt: 0)
            output += "\(name) \(ip) \(statusPadded) \(latencyPadded) \(packetLossPadded) \(notePadded)\n"
        }
        
        return output
    }
    
    /// Detailed display mode - full table with all metrics
    private func getDetailedDisplay() -> String {
        return getLiveDisplay() // Same as live for now
    }
    
    /// Get compact status line for simple display
    func getCompactStatus() -> String {
        let timestamp = DateFormatter.localizedString(from: lastUpdate, dateStyle: .none, timeStyle: .medium)
        return "[\(timestamp)] Total: \(totalDevices) | Online: \(onlineDevices) | Offline: \(offlineDevices)"
    }
    
    /// Start monitoring mode
    func startMonitoring() {
        isMonitoring = true
        PingManager.shared.startPingTimer()
    }
    
    /// Stop monitoring mode
    func stopMonitoring() {
        isMonitoring = false
        PingManager.shared.stopPingTimer()
    }
    
    /// Update display mode
    func setDisplayMode(_ mode: String) {
        displayMode = mode
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let cliDataUpdated = Notification.Name("cliDataUpdated")
}
