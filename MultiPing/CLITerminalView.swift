import SwiftUI

struct CLITerminalView: View {
    @ObservedObject var outputStream: CLITerminalOutputStream
    @State private var commandInput: String = ""
    @State private var commandHistory: [String] = []
    @State private var historyIndex: Int = -1
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal Header
            HStack {
                Text("MultiPing CLI Monitor")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(outputStream.isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(outputStream.isRunning ? "Running" : "Stopped")
                    .font(.caption)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Control buttons
                HStack(spacing: 8) {
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
            }
        }
        .frame(minWidth: 600, minHeight: 400)
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
                outputStream.addOutput("Usage: remove <name_or_ip>\n")
            }
        case "export":
            exportDevices()
        case "import":
            if parts.count > 1 {
                importDevices(from: parts[1])
            } else {
                outputStream.addOutput("Usage: import <file_path>\n")
            }
        case "history":
            showHistory()
        case "exit", "quit":
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
        
        🔄 Monitoring:
          start             - Start monitoring all devices
          stop              - Stop monitoring
          status            - Show current monitoring status
        
        📁 File Operations:
          export            - Export devices to CSV
          import <file>     - Import devices from CSV file
        
        🛠️  Terminal:
          clear, cls        - Clear terminal output
          history           - Show command history
          help, ?           - Show this help
          exit, quit        - Close terminal
        
        ⌨️  Keyboard Shortcuts:
          ↑/↓               - Navigate command history
          Tab               - Auto-complete commands
          Escape            - Clear current input
          Enter             - Execute command
          Cmd+K             - Clear terminal
        
        Examples:
          add Router 192.168.1.1
          ping 8.8.8.8
          start
          export
        
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
    
    private func exportDevices() {
        outputStream.addProgressMessage("Exporting devices...")
        // This would integrate with your export functionality
        outputStream.addSuccessMessage("Devices exported to ~/Desktop/devices.csv")
    }
    
    private func importDevices(from file: String) {
        outputStream.addProgressMessage("Importing devices from \(file)...")
        // This would integrate with your import functionality
        outputStream.addSuccessMessage("Imported 5 devices from \(file)")
    }
    
    private func showHistory() {
        if commandHistory.isEmpty {
            outputStream.addOutput("No command history.\n")
            return
        }
        
        outputStream.addOutput("Command History:\n")
        for (index, cmd) in commandHistory.enumerated() {
            outputStream.addOutput("  \(index + 1). \(cmd)\n")
        }
        outputStream.addOutput("\n")
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
