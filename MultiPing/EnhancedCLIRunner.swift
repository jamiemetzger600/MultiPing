//
//  EnhancedCLIRunner.swift
//  MultiPing
//
//  Created by Jamie Metzger on 4/6/25.
//

import Foundation
import AppKit

class EnhancedCLIRunner {
    static let shared = EnhancedCLIRunner()
    
    private let pythonCLIPath: URL
    private let tempDevicesFile: URL
    private var terminalWindowController: CLITerminalWindowController?
    
    init() {
        // Get the path to the embedded cli.py file
        guard let bundlePath = Bundle.main.resourcePath else {
            fatalError("Cannot access app bundle resources")
        }
        self.pythonCLIPath = URL(fileURLWithPath: bundlePath).appendingPathComponent("cli.py")
        
        // Create temporary file for device data
        let tempDir = FileManager.default.temporaryDirectory
        self.tempDevicesFile = tempDir.appendingPathComponent("multiping_devices_\(UUID().uuidString).txt")
        
        // Listen for terminal window close notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(terminalWindowWillClose(_:)),
            name: NSNotification.Name("CLITerminalWindowWillClose"),
            object: nil
        )
        
        // Listen for device changes to update CLI
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(devicesDidChange(_:)),
            name: NSNotification.Name("DevicesDidChange"),
            object: nil
        )
    }
    
    deinit {
        // Clean up temporary file and remove notification observer
        try? FileManager.default.removeItem(at: tempDevicesFile)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func terminalWindowWillClose(_ notification: Notification) {
        // Clear the reference to the terminal window controller when it closes
        DispatchQueue.main.async {
            self.terminalWindowController = nil
        }
    }
    
    @objc private func devicesDidChange(_ notification: Notification) {
        // Update CLI if it's running
        if terminalWindowController != nil {
            DispatchQueue.main.async {
                self.terminalWindowController?.refreshDevices()
            }
        }
    }
    
    /// Launch the enhanced Python CLI with current device data
    func launchCLIMonitor(interval: Double = 1.0, timeout: Double = 1.0, mode: String = "simple") {
        // Export current devices to temporary file
        guard exportDevicesToFile() else {
            showAlert(title: "CLI Launch Failed", message: "Failed to export device data for CLI monitoring.")
            return
        }
        
        // Launch Python CLI with device data
        launchPythonCLI(interval: interval, timeout: timeout, mode: mode)
    }
    
    /// Launch CLI with custom parameters
    func launchCLIMonitorAdvanced() {
        // Create a simple dialog for advanced options
        let alert = NSAlert()
        alert.messageText = "CLI Monitor Options"
        alert.informativeText = "Configure the CLI monitoring parameters:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Launch")
        alert.addButton(withTitle: "Cancel")
        
        // Create input fields for parameters
        let intervalField = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 22))
        intervalField.stringValue = "1.0"
        intervalField.placeholderString = "Refresh interval (seconds)"
        
        let timeoutField = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 22))
        timeoutField.stringValue = "1.0"
        timeoutField.placeholderString = "Ping timeout (seconds)"
        
        let modePopUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 120, height: 22))
        modePopUp.addItems(withTitles: ["simple", "detailed"])
        modePopUp.selectItem(withTitle: "simple")
        
        // Create stack view for layout
        let stackView = NSStackView(frame: NSRect(x: 0, y: 0, width: 300, height: 80))
        stackView.orientation = .vertical
        stackView.spacing = 8
        
        let intervalLabel = NSTextField(labelWithString: "Refresh Interval (seconds):")
        intervalLabel.font = NSFont.systemFont(ofSize: 12)
        
        let timeoutLabel = NSTextField(labelWithString: "Ping Timeout (seconds):")
        timeoutLabel.font = NSFont.systemFont(ofSize: 12)
        
        let modeLabel = NSTextField(labelWithString: "Display Mode:")
        modeLabel.font = NSFont.systemFont(ofSize: 12)
        
        stackView.addArrangedSubview(intervalLabel)
        stackView.addArrangedSubview(intervalField)
        stackView.addArrangedSubview(timeoutLabel)
        stackView.addArrangedSubview(timeoutField)
        stackView.addArrangedSubview(modeLabel)
        stackView.addArrangedSubview(modePopUp)
        
        alert.accessoryView = stackView
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let interval = Double(intervalField.stringValue) ?? 1.0
            let timeout = Double(timeoutField.stringValue) ?? 1.0
            let mode = modePopUp.selectedItem?.title ?? "simple"
            
            launchCLIMonitor(interval: interval, timeout: timeout, mode: mode)
        }
    }
    
    /// Quick launch with default settings
    func launchCLIMonitorQuick() {
        launchCLIMonitor()
    }
    
    private func exportDevicesToFile() -> Bool {
        let devices = PingManager.shared.devices
        
        guard !devices.isEmpty else {
            showAlert(title: "No Devices", message: "No devices found. Please add some devices in the main window first.")
            return false
        }
        
        do {
            var deviceLines: [String] = []
            deviceLines.append("# MultiPing Device Export")
            deviceLines.append("# Format: name:ip_address")
            deviceLines.append("# Generated on \(Date())")
            deviceLines.append("")
            
            for device in devices {
                // Use the format: name:ip_address
                // If device has a note, include it as a comment
                let line: String
                if let note = device.note, !note.isEmpty {
                    line = "\(device.name):\(device.ipAddress)  # \(note)"
                } else {
                    line = "\(device.name):\(device.ipAddress)"
                }
                deviceLines.append(line)
            }
            
            let content = deviceLines.joined(separator: "\n")
            try content.write(to: tempDevicesFile, atomically: true, encoding: .utf8)
            
            print("EnhancedCLIRunner: Exported \(devices.count) devices to \(tempDevicesFile.path)")
            return true
            
        } catch {
            print("EnhancedCLIRunner: Failed to export devices: \(error)")
            return false
        }
    }
    
    private func launchPythonCLI(interval: Double, timeout: Double, mode: String) {
        // Check if Python CLI file exists
        guard FileManager.default.fileExists(atPath: pythonCLIPath.path) else {
            showAlert(title: "CLI Not Found", message: "The CLI monitoring script could not be found. Please ensure the app was built correctly.")
            return
        }
        
        // Build the command arguments
        var arguments: [String] = []
        arguments.append(pythonCLIPath.path)
        arguments.append("-f")
        arguments.append(tempDevicesFile.path)
        arguments.append("-i")
        arguments.append(String(interval))
        arguments.append("-t")
        arguments.append(String(timeout))
        arguments.append("-m")
        arguments.append(mode)
        
        // Launch the Python script
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        task.arguments = arguments
        
        // Set up the Python path to include the app bundle resources and bundled libraries
        let bundlePath = Bundle.main.resourcePath ?? ""
        let pythonPath = "\(bundlePath):\(bundlePath)/site-packages:\(bundlePath)/colorama"
        task.environment = [
            "PYTHONPATH": pythonPath,
            "PYTHONUNBUFFERED": "1",
            "TERM": "xterm-256color",
            "TERM_PROGRAM": "MultiPing",
            "COLUMNS": "120",
            "LINES": "40"
        ]
        
        // Set up the task to run in Terminal
        do {
            try task.run()
            print("EnhancedCLIRunner: Launched Python CLI with \(arguments.count) arguments")
        } catch {
            print("EnhancedCLIRunner: Failed to launch Python CLI: \(error)")
            showAlert(title: "Launch Failed", message: "Failed to launch CLI monitor: \(error.localizedDescription)")
        }
    }
    
    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    /// Check if the Python CLI is available
    func isCLIAvailable() -> Bool {
        return FileManager.default.fileExists(atPath: pythonCLIPath.path)
    }
    
    /// Get the number of devices that would be monitored
    func getDeviceCount() -> Int {
        return PingManager.shared.devices.count
    }
    
    /// Get a summary of devices for display
    func getDeviceSummary() -> String {
        let devices = PingManager.shared.devices
        if devices.isEmpty {
            return "No devices configured"
        }
        
        let deviceNames = devices.map { $0.name }.joined(separator: ", ")
        if deviceNames.count > 50 {
            let truncated = String(deviceNames.prefix(47)) + "..."
            return "\(devices.count) devices: \(truncated)"
        } else {
            return "\(devices.count) devices: \(deviceNames)"
        }
    }
    
    // MARK: - Terminal Window Integration
    
    /// Launch CLI Monitor in system terminal (Quick Launch)
    /// Launch CLI Monitor with built-in terminal window (Quick Launch)
    func launchCLIMonitorWithTerminal() {
        let devices = PingManager.shared.devices
        
        guard !devices.isEmpty else {
            showAlert(title: "No Devices", message: "Please add some devices to monitor first.")
            return
        }
        
        // Launch CLI in built-in terminal window with default settings
        launchCLIInBuiltInTerminal(interval: 1.0, timeout: 1.0, mode: "simple")
    }
    
    /// Launch CLI Monitor with built-in terminal window (Advanced Options)
    func launchCLIMonitorAdvancedWithTerminal() {
        let devices = PingManager.shared.devices
        
        guard !devices.isEmpty else {
            showAlert(title: "No Devices", message: "Please add some devices to monitor first.")
            return
        }
        
        // Launch CLI in built-in terminal window with advanced settings
        launchCLIInBuiltInTerminal(interval: 2.0, timeout: 3.0, mode: "detailed")
    }
    
    /// Launch CLI in the built-in terminal window
    func launchCLIInBuiltInTerminal(interval: Double, timeout: Double, mode: String) {
        // Export devices to temporary file
        guard exportDevicesToFile() else {
            showAlert(title: "Export Error", message: "Failed to export devices to temporary file.")
            return
        }
        
        // Create or get existing terminal window controller
        if terminalWindowController == nil {
            terminalWindowController = CLITerminalWindowController()
        }
        
        // Configure the terminal with device data
        terminalWindowController?.configureWithDevices(
            devices: PingManager.shared.devices,
            interval: interval,
            timeout: timeout,
            mode: mode
        )
        
        // Show the terminal window
        terminalWindowController?.showWindow()
        
        print("EnhancedCLIRunner: Launched CLI in built-in terminal window")
    }
    
    /// Close the terminal window
    func closeTerminalWindow() {
        terminalWindowController?.closeTerminal()
        terminalWindowController = nil
    }
    
    /// Launch CLI in the user's system terminal application
    func launchCLIInSystemTerminal(interval: Double = 1.0, timeout: Double = 1.0, mode: String = "curses") {
        let devices = PingManager.shared.devices
        
        guard !devices.isEmpty else {
            showAlert(title: "No Devices", message: "Please add some devices to monitor first.")
            return
        }
        
        // Export devices to temporary file
        guard let tempFileURL = exportDevicesToTempFile(devices: devices) else {
            showAlert(title: "Export Error", message: "Failed to export devices to temporary file.")
            return
        }
        
        // Get the path to cli.py in the app bundle
        guard let cliPath = Bundle.main.path(forResource: "cli", ofType: "py") else {
            showAlert(title: "CLI Error", message: "cli.py not found in app bundle.")
            return
        }
        
        // Create the command to run
        let command = """
        cd "$(dirname "\(cliPath)")" && python3 cli.py --file "\(tempFileURL.path)" --interval \(interval) --timeout \(timeout) --mode \(mode)
        """
        
        // Create AppleScript to launch Terminal.app with the command
        let appleScript = """
        tell application "Terminal"
            activate
            do script "\(command)"
        end tell
        """
        
        // Execute the AppleScript
        let script = NSAppleScript(source: appleScript)
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        
        if let error = error {
            print("EnhancedCLIRunner: Failed to launch terminal: \(error)")
            
            // Check if it's a permission error
            let errorCode = error[NSAppleScript.errorNumber] as? Int ?? 0
            let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            
            var alertMessage = "Failed to launch Terminal.app.\n\n"
            
            if errorCode == -1743 || errorMessage.contains("not authorized") {
                alertMessage += "This app needs permission to control Terminal.app.\n\n"
                alertMessage += "To fix this:\n"
                alertMessage += "1. Go to System Preferences > Security & Privacy > Privacy\n"
                alertMessage += "2. Select 'Automation' from the left sidebar\n"
                alertMessage += "3. Find MultiPing in the list and check the box next to Terminal\n"
                alertMessage += "4. Restart MultiPing and try again\n\n"
                alertMessage += "Alternatively, you can use the built-in terminal window instead."
            } else {
                alertMessage += "Error: \(errorMessage) (Code: \(errorCode))\n\n"
                alertMessage += "Please make sure Terminal.app is installed and accessible."
            }
            
            showAlert(title: "Terminal Launch Error", message: alertMessage)
        } else {
            print("EnhancedCLIRunner: Successfully launched CLI in system terminal")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Export devices to a temporary file for CLI usage
    func exportDevicesToTempFile(devices: [Device]) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "multiping_devices_\(UUID().uuidString).txt"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        var content = ""
        var exportedCount = 0
        var skippedCount = 0
        var seenIPs = Set<String>()
        var duplicateIPs = Set<String>()
        
        for device in devices {
            let name = device.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let ip = device.ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip if name or IP is empty
            if name.isEmpty || ip.isEmpty {
                skippedCount += 1
                print("Skipped device - Name: '\(name)', IP: '\(ip)' (empty)")
                continue
            }
            
            // Clean up malformed names (remove extra parentheses, etc.)
            let cleanName = name.replacingOccurrences(of: "\\s*\\([^)]*$", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip if name becomes empty after cleaning
            if cleanName.isEmpty {
                skippedCount += 1
                print("Skipped device - Name: '\(name)' (invalid after cleaning), IP: '\(ip)'")
                continue
            }
            
            // Check for duplicate IPs
            if seenIPs.contains(ip) {
                duplicateIPs.insert(ip)
                skippedCount += 1
                print("Skipped device - Name: '\(cleanName)', IP: '\(ip)' (duplicate IP)")
                continue
            }
            
            seenIPs.insert(ip)
            content += "\(cleanName):\(ip)\n"
            exportedCount += 1
        }
        
        print("Export summary: \(exportedCount) exported, \(skippedCount) skipped out of \(devices.count) total devices")
        if !duplicateIPs.isEmpty {
            print("Duplicate IPs found: \(duplicateIPs.joined(separator: ", "))")
        }
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Exported devices to: \(fileURL.path)")
            print("File content:\n\(content)")
            return fileURL
        } catch {
            print("Error writing devices to temp file: \(error)")
            return nil
        }
    }
    
    /// Show advanced options dialog for CLI configuration
    private func showAdvancedOptionsDialog(completion: @escaping (Double, Double, String) -> Void) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "CLI Monitor - Advanced Options"
            alert.informativeText = "Configure the CLI monitoring settings:"
            alert.alertStyle = .informational
            
            // Create labeled input fields
            let intervalLabel = NSTextField(labelWithString: "Ping Interval (seconds):")
            intervalLabel.font = NSFont.systemFont(ofSize: 13)
            
            let intervalField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
            intervalField.placeholderString = "1.0"
            intervalField.stringValue = "1.0"
            intervalField.font = NSFont.systemFont(ofSize: 13)
            
            let timeoutLabel = NSTextField(labelWithString: "Ping Timeout (seconds):")
            timeoutLabel.font = NSFont.systemFont(ofSize: 13)
            
            let timeoutField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
            timeoutField.placeholderString = "1.0"
            timeoutField.stringValue = "1.0"
            timeoutField.font = NSFont.systemFont(ofSize: 13)
            
            let modeLabel = NSTextField(labelWithString: "Display Mode:")
            modeLabel.font = NSFont.systemFont(ofSize: 13)
            
            let modeField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
            modeField.placeholderString = "live"
            modeField.stringValue = "live"
            modeField.font = NSFont.systemFont(ofSize: 13)
            
            let modeHelpLabel = NSTextField(labelWithString: "(Options: curses, live, simple, detailed, compact)")
            modeHelpLabel.font = NSFont.systemFont(ofSize: 11)
            modeHelpLabel.textColor = .secondaryLabelColor
            
            // Create stack view for input fields with labels
            let stackView = NSStackView(frame: NSRect(x: 0, y: 0, width: 300, height: 160))
            stackView.orientation = .vertical
            stackView.spacing = 6
            stackView.alignment = .leading
            
            // Add interval section
            stackView.addArrangedSubview(intervalLabel)
            stackView.addArrangedSubview(intervalField)
            
            let separator1 = NSBox()
            separator1.boxType = .separator
            separator1.frame.size.height = 1
            stackView.addArrangedSubview(separator1)
            
            // Add timeout section
            stackView.addArrangedSubview(timeoutLabel)
            stackView.addArrangedSubview(timeoutField)
            
            let separator2 = NSBox()
            separator2.boxType = .separator
            separator2.frame.size.height = 1
            stackView.addArrangedSubview(separator2)
            
            // Add mode section
            stackView.addArrangedSubview(modeLabel)
            stackView.addArrangedSubview(modeField)
            stackView.addArrangedSubview(modeHelpLabel)
            
            alert.accessoryView = stackView
            
            alert.addButton(withTitle: "Start Monitor")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            
            if response == .alertFirstButtonReturn {
                let interval = Double(intervalField.stringValue) ?? 1.0
                let timeout = Double(timeoutField.stringValue) ?? 1.0
                let mode = modeField.stringValue.isEmpty ? "simple" : modeField.stringValue
                
                completion(interval, timeout, mode)
            }
        }
    }
}
