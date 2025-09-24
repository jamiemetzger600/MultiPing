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
    
    /// Get formatted device data for CLI display
    func getFormattedDeviceData() -> String {
        var output = ""
        
        // Safety check
        guard !devices.isEmpty else {
            return "No devices to monitor\n"
        }
        
        // Header with statistics
        let timestamp = DateFormatter.localizedString(from: lastUpdate, dateStyle: .none, timeStyle: .medium)
        output += "MultiPing Live Monitor - Last Update: \(timestamp)\n"
        output += "=" + String(repeating: "=", count: 60) + "\n"
        output += "Total: \(totalDevices) | Online: \(onlineDevices) | Offline: \(offlineDevices) | Interval: \(pingInterval)s\n"
        output += "-" + String(repeating: "-", count: 60) + "\n"
        
        // Device table header
        let nameHeader = "NAME".padding(toLength: 20, withPad: " ", startingAt: 0)
        let ipHeader = "IP ADDRESS".padding(toLength: 18, withPad: " ", startingAt: 0)
        let statusHeader = "STATUS".padding(toLength: 8, withPad: " ", startingAt: 0)
        let noteHeader = "NOTE".padding(toLength: 12, withPad: " ", startingAt: 0)
        output += "\(nameHeader) \(ipHeader) \(statusHeader) \(noteHeader)\n"
        output += "-" + String(repeating: "-", count: 60) + "\n"
        
        // Device rows
        for device in devices {
            let status = device.isReachable ? "🟢 UP" : "🔴 DOWN"
            let note = device.note?.isEmpty == false ? device.note! : "-"
            let truncatedNote = note.count > 10 ? String(note.prefix(10)) + "..." : note
            
            let name = device.name.padding(toLength: 20, withPad: " ", startingAt: 0)
            let ip = device.ipAddress.padding(toLength: 18, withPad: " ", startingAt: 0)
            let statusPadded = status.padding(toLength: 8, withPad: " ", startingAt: 0)
            let notePadded = truncatedNote.padding(toLength: 12, withPad: " ", startingAt: 0)
            output += "\(name) \(ip) \(statusPadded) \(notePadded)\n"
        }
        
        return output
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
    
    deinit {
        updateTimer?.invalidate()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let cliDataUpdated = Notification.Name("cliDataUpdated")
}
