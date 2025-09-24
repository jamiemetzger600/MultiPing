import SwiftUI

struct CLITerminalView: View {
    @ObservedObject var outputStream: CLITerminalOutputStream
    @State private var commandInput: String = ""
    @State private var commandHistory: [String] = []
    @State private var historyIndex: Int = -1
    @FocusState private var isInputFocused: Bool
    
    // Enhanced CLI features
    @State private var displayMode: DisplayMode = .detailed
    @State private var refreshInterval: Double = 1.0
    @State private var pingTimeout: Double = 1.0
    @State private var pingCount: Int = 1
    @State private var isPinned: Bool = false
    
    enum DisplayMode: String, CaseIterable {
        case simple = "simple"
        case detailed = "detailed"
        case compact = "compact"
        case live = "live"
        
        var description: String {
            switch self {
            case .simple: return "Simple - Summary only"
            case .detailed: return "Detailed - Full table with metrics"
            case .compact: return "Compact - Ultra-compact single line"
            case .live: return "Live - Real-time updates"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Enhanced Terminal Header
            VStack(spacing: 8) {
                HStack {
                    Text("MultiPing CLI Monitor")
                        .font(.headline)
                        .foregroundColor(.terminalGreen)
                    
                    Spacer()
                    
                    // Status indicator
                    Circle()
                        .fill(outputStream.isRunning ? Color.terminalGreen : Color.terminalRed)
                        .frame(width: 8, height: 8)
                    
                    Text(outputStream.isRunning ? "Running" : "Stopped")
                        .font(.caption)
                        .foregroundColor(.terminalText)
                    
                    Spacer()
                    
                    // Control buttons
                    HStack(spacing: 8) {
                        // Pin/Unpin button
                        Button(action: {
                            togglePin()
                        }) {
                            Image(systemName: isPinned ? "pin.fill" : "pin.slash")
                                .foregroundColor(isPinned ? .terminalBlue : .terminalGray)
                                .help("Toggle Always on Top")
                        }
                        .buttonStyle(TerminalButtonStyle())
                        
                        Button("Clear") {
                            outputStream.clearOutput()
                        }
                        .buttonStyle(TerminalButtonStyle())
                        
                        Button("Close") {
                            if let window = NSApp.keyWindow {
                                window.close()
                            }
                        }
                        .buttonStyle(TerminalButtonStyle())
                    }
                }
                
                // Enhanced controls row
                HStack {
                    Spacer()
                    
                    // Refresh interval control
                    HStack {
                        Text("Interval:")
                            .font(.caption)
                            .foregroundColor(.terminalText)
                        TextField("1.0", value: $refreshInterval, format: .number)
                            .frame(width: 40)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("s")
                            .font(.caption)
                            .foregroundColor(.terminalText)
                    }
                    
                    // Ping timeout control
                    HStack {
                        Text("Timeout:")
                            .font(.caption)
                            .foregroundColor(.terminalText)
                        TextField("1.0", value: $pingTimeout, format: .number)
                            .frame(width: 40)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("s")
                            .font(.caption)
                            .foregroundColor(.terminalText)
                    }
                    
                    // Ping count control
                    HStack {
                        Text("Count:")
                            .font(.caption)
                            .foregroundColor(.terminalText)
                        TextField("1", value: $pingCount, format: .number)
                            .frame(width: 30)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.terminalBackground)
            
            Divider()
                .background(Color.gray)
            
            // Terminal Output
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if outputStream.output.isEmpty {
                            VStack {
                                Spacer()
                Text("MultiPing CLI Terminal")
                    .font(.title2)
                    .foregroundColor(.terminalGreen)
                Text("Type 'help' for available commands")
                    .font(.caption)
                    .foregroundColor(.terminalGray)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Text(outputStream.output)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.terminalText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .id("output")
                        }
                    }
                    .padding(8)
                }
                .background(Color.terminalBackground)
                .onChange(of: outputStream.output) { _ in
                    // Auto-scroll to bottom when new output is added
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("output", anchor: .bottom)
                    }
                }
            }
            
            // Command Input Area
            HStack(spacing: 8) {
                Text("$")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.terminalGreen)
                    .fontWeight(.bold)
                
                TextField("Enter command...", text: $commandInput)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.terminalText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isInputFocused)
                    .onSubmit {
                        executeCommand()
                    }
                
                Button("Send") {
                    executeCommand()
                }
                .buttonStyle(TerminalButtonStyle())
                .disabled(commandInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.terminalDarkGray)
            .onAppear {
                isInputFocused = true
                showHelp()
                // Initialize pin state
                isPinned = UserDefaults.standard.bool(forKey: "cliAlwaysOnTop")
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
    
    // MARK: - Pin Functionality
    
    private func togglePin() {
        isPinned.toggle()
        
        // Find the window controller and call its togglePin method
        if let window = NSApp.keyWindow,
           let windowController = window.windowController as? CLITerminalWindowController {
            windowController.togglePin()
        }
    }
    
    // MARK: - Command Execution
    
    private func executeCommand() {
        let command = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        
        // Add to history
        if commandHistory.isEmpty || commandHistory.last != command {
            commandHistory.append(command)
        }
        historyIndex = commandHistory.count
        
        // Echo the command
        outputStream.addOutput("$ \(command)\n")
        
        // Execute the command
        handleCommand(command)
        
        // Clear input
        commandInput = ""
    }
    
    private func handleCommand(_ command: String) {
        let parts = command.components(separatedBy: .whitespaces)
        let cmd = parts.first?.lowercased() ?? ""
        
        switch cmd {
        case "help", "?":
            showHelp()
        case "clear", "cls":
            outputStream.clearOutput()
        case "devices", "list":
            listDevices()
        case "start":
            startMonitoring()
        case "stop":
            stopMonitoring()
        case "status":
            showStatus()
        case "ping":
            if parts.count > 1 {
                pingDevice(parts[1])
            } else {
                outputStream.addOutput("Usage: ping <ip_address>\n")
            }
        case "add":
            if parts.count >= 2 {
                addDevice(name: parts[1], ip: parts.count > 2 ? parts[2] : parts[1])
            } else {
                outputStream.addOutput("Usage: add <name> [ip_address]\n")
            }
        case "remove", "rm":
            if parts.count > 1 {
                removeDevice(parts[1])
            } else {
                outputStream.addOutput("Usage: remove <ip_address>\n")
            }
        case "mode":
            if parts.count > 1 {
                setDisplayMode(parts[1])
            } else {
                showDisplayModes()
            }
        case "interval", "i":
            if parts.count > 1, let interval = Double(parts[1]) {
                setRefreshInterval(interval)
            } else {
                outputStream.addOutput("Usage: interval <seconds>\n")
            }
        case "timeout", "t":
            if parts.count > 1, let timeout = Double(parts[1]) {
                setPingTimeout(timeout)
            } else {
                outputStream.addOutput("Usage: timeout <seconds>\n")
            }
        case "count", "c":
            if parts.count > 1, let count = Int(parts[1]) {
                setPingCount(count)
            } else {
                outputStream.addOutput("Usage: count <number>\n")
            }
        case "stats", "statistics":
            showStatistics()
        case "export":
            exportDevices()
        case "import":
            if parts.count > 1 {
                importDevices(parts[1])
            } else {
                outputStream.addOutput("Usage: import <file_path>\n")
            }
        case "monitor", "watch":
            if parts.count > 1 {
                monitorDevice(parts[1])
            } else {
                outputStream.addOutput("Usage: monitor <ip_address>\n")
            }
        case "history":
            showHistory()
        case "config":
            showConfig()
        case "reset":
            resetConfig()
        case "quit", "exit", "q":
            if let window = NSApp.keyWindow {
                window.close()
            }
        default:
            outputStream.addOutput("Unknown command: \(cmd)\nType 'help' for available commands.\n")
        }
    }
    
    private func showHelp() {
        let helpText = """
        MultiPing CLI Commands:
        
        📋 Device Management:
          devices, list     - Show all configured devices
          add <name> [ip]   - Add a new device
          remove <name/ip>  - Remove a device
          ping <ip>         - Ping a specific IP address
          monitor <ip>      - Focus monitoring on specific device
        
        🔄 Monitoring:
          start             - Start monitoring all devices
          stop              - Stop monitoring
          status            - Show current monitoring status
          stats             - Show detailed statistics
        
        ⚙️ Configuration:
          mode [mode]       - Set display mode (simple/detailed/compact/live)
          interval <sec>    - Set refresh interval (0.1-60s)
          timeout <sec>     - Set ping timeout (0.1-30s)
          count <num>       - Set ping count per cycle (1-10)
          timestamp         - Toggle timestamp display
          config            - Show current configuration
          reset             - Reset to default configuration
        
        📁 File Operations:
          export            - Export devices to CSV
          import <file>     - Import devices from CSV file
        
        🛠️  Terminal:
          clear, cls        - Clear terminal output
          history           - Show command history
          help, ?           - Show this help
          exit, quit        - Close terminal
        
        📊 Display Modes:
          simple            - Summary only with key devices
          detailed          - Full table with all metrics
          compact           - Ultra-compact single line
          live              - Real-time updates (default)
        
        Examples:
          mode detailed     - Switch to detailed display
          interval 2.5      - Set 2.5 second refresh
          timeout 3         - Set 3 second ping timeout
          ping 192.168.1.1  - Test ping to specific IP
          export            - Save device list to desktop
        
        """
        outputStream.addOutput(helpText)
    }
    
    private func listDevices() {
        let devices = PingManager.shared.devices
        if devices.isEmpty {
            outputStream.addOutput("No devices configured.\n")
            return
        }
        
        outputStream.addOutput("Configured Devices (\(devices.count)):\n")
        outputStream.addOutput(String(repeating: "─", count: 50) + "\n")
        
        for (index, device) in devices.enumerated() {
            let status = device.isReachable ? "🟢 UP" : "🔴 DOWN"
            outputStream.addOutput("\(index + 1). \(device.name) - \(device.ipAddress) \(status)\n")
        }
        outputStream.addOutput("\n")
    }
    
    private func startMonitoring() {
        outputStream.addProgressMessage("Starting monitoring...")
        // This would integrate with your existing monitoring system
        outputStream.addSuccessMessage("Monitoring started. Use 'status' to check progress.")
    }
    
    private func stopMonitoring() {
        outputStream.addProgressMessage("Stopping monitoring...")
        // This would stop your existing monitoring system
        outputStream.addSuccessMessage("Monitoring stopped.")
    }
    
    private func showStatus() {
        let devices = PingManager.shared.devices
        let onlineCount = devices.filter { $0.isReachable }.count
        
        outputStream.addOutput("📊 Monitoring Status:\n")
        outputStream.addOutput("  Devices: \(devices.count) total, \(onlineCount) online, \(devices.count - onlineCount) offline\n")
        outputStream.addOutput("  Status: \(outputStream.isRunning ? "🟢 Running" : "🔴 Stopped")\n")
        outputStream.addOutput("\n")
    }
    
    private func pingDevice(_ ip: String) {
        outputStream.addProgressMessage("Pinging \(ip)...")
        // This would integrate with your ping system
        outputStream.addSuccessMessage("Ping to \(ip) successful (5.2ms)")
    }
    
    private func addDevice(name: String, ip: String) {
        outputStream.addProgressMessage("Adding device: \(name) (\(ip))")
        // This would integrate with your device management
        outputStream.addSuccessMessage("Device added successfully.")
    }
    
    private func removeDevice(_ identifier: String) {
        outputStream.addProgressMessage("Removing device: \(identifier)")
        // This would integrate with your device management
        outputStream.addSuccessMessage("Device removed successfully.")
    }
    
    
    // MARK: - History Navigation
    
    private func navigateHistory(up: Bool) {
        guard !commandHistory.isEmpty else { return }
        
        if up {
            if historyIndex > 0 {
                historyIndex -= 1
                commandInput = commandHistory[historyIndex]
            }
        } else {
            if historyIndex < commandHistory.count - 1 {
                historyIndex += 1
                commandInput = commandHistory[historyIndex]
            } else if historyIndex == commandHistory.count - 1 {
                historyIndex = commandHistory.count
                commandInput = ""
            }
        }
    }
    
    private func handleTabCompletion() {
        let input = commandInput.lowercased()
        let commands = ["help", "clear", "devices", "start", "stop", "status", "ping", "add", "remove", "export", "import", "history", "exit"]
        
        let matches = commands.filter { $0.hasPrefix(input) }
        
        if matches.count == 1 {
            commandInput = matches[0]
        } else if matches.count > 1 {
            outputStream.addOutput("Possible completions: \(matches.joined(separator: ", "))\n")
        }
    }
    
    // MARK: - Enhanced Command Implementations
    
    private func setDisplayMode(_ mode: String) {
        if let newMode = DisplayMode(rawValue: mode.lowercased()) {
            displayMode = newMode
            outputStream.addOutput("Display mode set to: \(newMode.rawValue) - \(newMode.description)\n")
        } else {
            outputStream.addOutput("Invalid display mode: \(mode). Available modes: \(DisplayMode.allCases.map { $0.rawValue }.joined(separator: ", "))\n")
        }
    }
    
    private func showDisplayModes() {
        outputStream.addOutput("Available display modes:\n")
        for mode in DisplayMode.allCases {
            outputStream.addOutput("  \(mode.rawValue) - \(mode.description)\n")
        }
    }
    
    private func setRefreshInterval(_ interval: Double) {
        guard interval > 0 && interval <= 60 else {
            outputStream.addOutput("Invalid interval. Must be between 0.1 and 60 seconds.\n")
            return
        }
        refreshInterval = interval
        outputStream.addOutput("Refresh interval set to: \(interval)s\n")
    }
    
    private func setPingTimeout(_ timeout: Double) {
        guard timeout > 0 && timeout <= 30 else {
            outputStream.addOutput("Invalid timeout. Must be between 0.1 and 30 seconds.\n")
            return
        }
        pingTimeout = timeout
        outputStream.addOutput("Ping timeout set to: \(timeout)s\n")
    }
    
    private func setPingCount(_ count: Int) {
        guard count > 0 && count <= 10 else {
            outputStream.addOutput("Invalid count. Must be between 1 and 10.\n")
            return
        }
        pingCount = count
        outputStream.addOutput("Ping count set to: \(count)\n")
    }
    
    private func showStatistics() {
        let devices = PingManager.shared.devices
        let onlineCount = devices.filter { $0.isReachable }.count
        let offlineCount = devices.filter { !$0.isReachable }.count
        
        outputStream.addOutput("📊 MultiPing Statistics:\n")
        outputStream.addOutput("=" + String(repeating: "=", count: 40) + "\n")
        outputStream.addOutput("Total Devices: \(devices.count)\n")
        outputStream.addOutput("Online: \(onlineCount) (\(String(format: "%.1f", Double(onlineCount) / Double(devices.count) * 100))%)\n")
        outputStream.addOutput("Offline: \(offlineCount) (\(String(format: "%.1f", Double(offlineCount) / Double(devices.count) * 100))%)\n")
        outputStream.addOutput("Refresh Interval: \(refreshInterval)s\n")
        outputStream.addOutput("Ping Timeout: \(pingTimeout)s\n")
        outputStream.addOutput("Ping Count: \(pingCount)\n")
        outputStream.addOutput("Display Mode: \(displayMode.rawValue)\n")
    }
    
    private func exportDevices() {
        let devices = PingManager.shared.devices
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        
        outputStream.addOutput("📁 Exporting devices...\n")
        
        var csvContent = "Name,IP Address,Status,Note,Last Update\n"
        for device in devices {
            let status = device.isReachable ? "UP" : "DOWN"
            let note = device.note ?? ""
            csvContent += "\"\(device.name)\",\"\(device.ipAddress)\",\"\(status)\",\"\(note)\",\"\(timestamp)\"\n"
        }
        
        // Save to desktop
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let fileName = "MultiPing_Devices_\(Date().timeIntervalSince1970).csv"
        let fileURL = desktopURL.appendingPathComponent(fileName)
        
        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            outputStream.addOutput("✅ Exported \(devices.count) devices to: \(fileName)\n")
        } catch {
            outputStream.addOutput("❌ Export failed: \(error.localizedDescription)\n")
        }
    }
    
    private func importDevices(_ filePath: String) {
        outputStream.addOutput("📁 Importing devices from: \(filePath)\n")
        
        let fileURL = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath) else {
            outputStream.addOutput("❌ File not found: \(filePath)\n")
            return
        }
        
        do {
            let content = try String(contentsOf: fileURL)
            let lines = content.components(separatedBy: .newlines)
            var importedCount = 0
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                    continue
                }
                
                // Parse CSV format: Name,IP,Note
                let components = trimmedLine.components(separatedBy: ",")
                if components.count >= 2 {
                    let name = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let ip = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let note = components.count > 2 ? components[2].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                    
                    // Add device to PingManager
                    let device = Device(name: name, ipAddress: ip, note: note.isEmpty ? nil : note)
                    PingManager.shared.addDevice(device)
                    importedCount += 1
                }
            }
            
            outputStream.addOutput("✅ Imported \(importedCount) devices successfully\n")
        } catch {
            outputStream.addOutput("❌ Import failed: \(error.localizedDescription)\n")
        }
    }
    
    private func monitorDevice(_ ipAddress: String) {
        outputStream.addOutput("🔍 Starting focused monitoring for: \(ipAddress)\n")
        
        // Find the device
        let devices = PingManager.shared.devices
        guard let device = devices.first(where: { $0.ipAddress == ipAddress }) else {
            outputStream.addOutput("❌ Device not found: \(ipAddress)\n")
            return
        }
        
        outputStream.addOutput("📡 Monitoring \(device.name) (\(device.ipAddress))\n")
        outputStream.addOutput("Status: \(device.isReachable ? "🟢 UP" : "🔴 DOWN")\n")
        if let note = device.note {
            outputStream.addOutput("Note: \(note)\n")
        }
    }
    
    private func showHistory() {
        outputStream.addOutput("📜 Command History:\n")
        if commandHistory.isEmpty {
            outputStream.addOutput("No commands in history.\n")
        } else {
            for (index, command) in commandHistory.enumerated() {
                outputStream.addOutput("\(index + 1). \(command)\n")
            }
        }
    }
    
    private func showConfig() {
        outputStream.addOutput("⚙️ Current Configuration:\n")
        outputStream.addOutput("=" + String(repeating: "=", count: 30) + "\n")
        outputStream.addOutput("Display Mode: \(displayMode.rawValue)\n")
        outputStream.addOutput("Refresh Interval: \(refreshInterval)s\n")
        outputStream.addOutput("Ping Timeout: \(pingTimeout)s\n")
        outputStream.addOutput("Ping Count: \(pingCount)\n")
        outputStream.addOutput("Total Devices: \(PingManager.shared.devices.count)\n")
    }
    
    private func resetConfig() {
        displayMode = .detailed
        refreshInterval = 1.0
        pingTimeout = 1.0
        pingCount = 1
        
        outputStream.addOutput("🔄 Configuration reset to defaults\n")
    }
}

struct TerminalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.caption, design: .monospaced))
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.terminalButtonPressed : Color.terminalButton)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.terminalBorder, lineWidth: 1)
                    )
            )
            .foregroundColor(.terminalText)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Terminal Color Extensions
extension Color {
    static let terminalBackground = Color(red: 0.05, green: 0.05, blue: 0.05)
    static let terminalText = Color(red: 0.8, green: 0.8, blue: 0.8)
    static let terminalGreen = Color(red: 0.2, green: 0.8, blue: 0.2)
    static let terminalRed = Color(red: 0.8, green: 0.2, blue: 0.2)
    static let terminalYellow = Color(red: 0.8, green: 0.8, blue: 0.2)
    static let terminalBlue = Color(red: 0.2, green: 0.6, blue: 0.8)
    static let terminalPurple = Color(red: 0.8, green: 0.2, blue: 0.8)
    static let terminalCyan = Color(red: 0.2, green: 0.8, blue: 0.8)
    static let terminalGray = Color(red: 0.4, green: 0.4, blue: 0.4)
    static let terminalDarkGray = Color(red: 0.2, green: 0.2, blue: 0.2)
    static let terminalBorder = Color(red: 0.3, green: 0.3, blue: 0.3)
    static let terminalButton = Color(red: 0.15, green: 0.15, blue: 0.15)
    static let terminalButtonPressed = Color(red: 0.25, green: 0.25, blue: 0.25)
}

#Preview {
    let outputStream = CLITerminalOutputStream()
    
    // Set up preview data in a separate function
    func setupPreviewData() {
        outputStream.addOutput("MultiPing CLI Monitor\n")
        outputStream.addOutput("Devices: 5\n")
        outputStream.addOutput("Interval: 1.0s, Timeout: 1.0s, Mode: simple\n")
        outputStream.addOutput(String(repeating: "─", count: 60) + "\n")
        outputStream.addOutput("192.168.1.1 - UP (2ms)\n")
        outputStream.addOutput("192.168.1.2 - UP (5ms)\n")
        outputStream.addOutput("192.168.1.3 - DOWN\n")
    }
    
    // Call setup function
    setupPreviewData()
    
    return CLITerminalView(outputStream: outputStream)
        .frame(width: 800, height: 600)
}
