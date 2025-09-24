import Cocoa
import SwiftUI
import Combine

class CLITerminalWindowController: NSWindowController, NSWindowDelegate {
    private var terminalView: CLITerminalView?
    private var outputStream: CLITerminalOutputStream?
    private var cliProcess: Process?
    
    // Configuration properties
    private var devices: [Device] = []
    private var interval: Double = 1.0
    private var timeout: Double = 1.0
    private var mode: String = "simple"
    
    init() {
        // Create the terminal window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "MultiPing CLI Monitor"
        window.center()
        window.setFrameAutosaveName("CLITerminalWindow")
        
        super.init(window: window)
        
        setupTerminalView()
        
        // Set up window delegate to handle cleanup when window is closed
        window.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupTerminalView() {
        outputStream = CLITerminalOutputStream()
        terminalView = CLITerminalView(outputStream: outputStream!)
        
        let hostingView = NSHostingView(rootView: terminalView!)
        window?.contentView = hostingView
        
        // Make the window front and key
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func startCLIMonitor(with devices: [Device], interval: Double = 1.0, timeout: Double = 1.0, mode: String = "simple") {
        let startTime = Date()
        
        outputStream?.clearOutput()
        outputStream?.addOutput("Starting MultiPing CLI Monitor...\n")
        outputStream?.addOutput("Devices: \(devices.count)\n")
        outputStream?.addOutput("Interval: \(interval)s, Timeout: \(timeout)s, Mode: \(mode)\n")
        outputStream?.addOutput(String(repeating: "─", count: 60) + "\n")
        
        // Show immediate feedback
        outputStream?.addOutput("⏳ Initializing CLI process...\n")
        
        // Launch the CLI in a background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.runCLIProcess(devices: devices, interval: interval, timeout: timeout, mode: mode, startTime: startTime)
        }
    }
    
    private func runCLIProcess(devices: [Device], interval: Double, timeout: Double, mode: String, startTime: Date) {
        let cliRunner = EnhancedCLIRunner()
        
        DispatchQueue.main.async {
            self.outputStream?.addOutput("📝 Exporting devices to temporary file...\n")
        }
        
        let exportStart = Date()
        // Export devices to temporary file
        guard let tempFileURL = cliRunner.exportDevicesToTempFile(devices: devices) else {
            DispatchQueue.main.async {
                self.outputStream?.addOutput("❌ Error: Failed to export devices to temporary file\n")
            }
            return
        }
        
        let exportTime = Date().timeIntervalSince(exportStart)
        
        DispatchQueue.main.async {
            self.outputStream?.addOutput("✅ Exported \(devices.count) devices to: \(tempFileURL.path) (\(String(format: "%.2f", exportTime))s)\n")
            self.outputStream?.addOutput("🐍 Launching Python CLI...\n\n")
        }
        
        // Create the Python process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        self.cliProcess = process
        
            // Set up the Python path to include the app bundle resources and bundled libraries
            let bundlePath = Bundle.main.resourcePath ?? ""
            let pythonPath = "\(bundlePath):\(bundlePath)/site-packages:\(bundlePath)/colorama"
            process.environment = [
                "PYTHONPATH": pythonPath,
                "PYTHONUNBUFFERED": "1",
                "TERM": "xterm-256color",
                "TERM_PROGRAM": "MultiPing",
                "COLUMNS": "120",
                "LINES": "40"
            ]
        
        // Get the cli.py path from the app bundle
        guard let cliPath = Bundle.main.path(forResource: "cli", ofType: "py") else {
            DispatchQueue.main.async {
                self.outputStream?.addOutput("Error: cli.py not found in app bundle\n")
            }
            return
        }
        
        process.arguments = [
            cliPath,
            "--file", tempFileURL.path,
            "--interval", String(interval),
            "--timeout", String(timeout),
            "--mode", mode
        ]
        
        // Set up pipes for output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Set up output monitoring
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty {
                let output = String(data: data, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    self?.outputStream?.addOutput(output)
                }
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty {
                let error = String(data: data, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    self?.outputStream?.addOutput("ERROR: \(error)")
                }
            }
        }
        
        // Handle process termination
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                if process.terminationStatus == 0 {
                    self?.outputStream?.addOutput("\n\nCLI Monitor stopped successfully.\n")
                } else {
                    self?.outputStream?.addOutput("\n\nCLI Monitor stopped with exit code: \(process.terminationStatus)\n")
                }
            }
        }
        
        // Start the process
        do {
            try process.run()
        } catch {
            DispatchQueue.main.async {
                self.outputStream?.addOutput("Error launching CLI: \(error.localizedDescription)\n")
            }
        }
    }
    
    func clearOutput() {
        outputStream?.clearOutput()
    }
    
    func closeTerminal() {
        // Stop live monitoring
        outputStream?.stopLiveMode()
        CLIDataBridge.shared.stopMonitoring()
        
        // Stop any running CLI process
        if let process = cliProcess, process.isRunning {
            process.terminate()
        }
        cliProcess = nil
        
        window?.close()
    }
    
    /// Configure the terminal with device data and settings
    func configureWithDevices(devices: [Device], interval: Double, timeout: Double, mode: String) {
        // Store the configuration
        self.devices = devices
        self.interval = interval
        self.timeout = timeout
        self.mode = mode
        
        // Update the output stream with initial information
        outputStream?.addSuccessMessage("CLI Terminal configured with \(devices.count) devices")
        outputStream?.addInfoMessage("Interval: \(interval)s, Timeout: \(timeout)s, Mode: \(mode)")
        
        // Start live monitoring mode
        outputStream?.startLiveMode()
        
        // Start the data bridge monitoring
        CLIDataBridge.shared.startMonitoring()
    }
    
    /// Show the terminal window
    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func refreshDevices() {
        // Export updated devices and restart CLI if running
        guard let process = cliProcess, process.isRunning else {
            return // CLI not running, nothing to refresh
        }
        
        // Get current devices from PingManager
        let devices = PingManager.shared.devices
        
        // Export devices to temporary file
        let cliRunner = EnhancedCLIRunner()
        guard cliRunner.exportDevicesToTempFile(devices: devices) != nil else {
            DispatchQueue.main.async {
                self.outputStream?.addOutput("❌ Error: Failed to refresh device data\n")
            }
            return
        }
        
        // Send refresh command to CLI process
        DispatchQueue.main.async {
            self.outputStream?.addOutput("🔄 Refreshing device list... (\(devices.count) devices)\n")
        }
        
        // Note: The Python CLI will automatically detect the updated file on its next cycle
        // We could implement a more sophisticated refresh mechanism, but this is simpler
        // and works with the existing CLI design
    }
}

// Observable class to handle terminal output
class CLITerminalOutputStream: ObservableObject {
    @Published var output: String = ""
    @Published var isRunning: Bool = false
    
    private let maxOutputLength = 10000 // Limit output to prevent memory issues
    private var outputLines: [TerminalLine] = []
    private var updateTimer: Timer?
    private var isLiveMode: Bool = false
    private var isUpdating: Bool = false
    
    init() {
        setupLiveUpdates()
    }
    
    func addOutput(_ text: String) {
        DispatchQueue.main.async {
            // Parse the text for color codes and formatting
            let lines = text.components(separatedBy: .newlines)
            for line in lines {
                if !line.isEmpty {
                    let terminalLine = TerminalLine(content: line, timestamp: Date())
                    self.outputLines.append(terminalLine)
                }
            }
            
            // Update the display output
            self.updateDisplayOutput()
            
            // Trim output if it gets too long
            if self.outputLines.count > 1000 {
                self.outputLines = Array(self.outputLines.suffix(800))
                self.updateDisplayOutput()
            }
        }
    }
    
    func clearOutput() {
        DispatchQueue.main.async {
            self.output = ""
            self.outputLines.removeAll()
        }
    }
    
    func setRunning(_ running: Bool) {
        DispatchQueue.main.async {
            self.isRunning = running
        }
    }
    
    private func updateDisplayOutput() {
        self.output = outputLines.map { $0.content }.joined(separator: "\n")
    }
    
    func addSuccessMessage(_ message: String) {
        addOutput("✅ \(message)\n")
    }
    
    func addErrorMessage(_ message: String) {
        addOutput("❌ \(message)\n")
    }
    
    func addWarningMessage(_ message: String) {
        addOutput("⚠️  \(message)\n")
    }
    
    func addInfoMessage(_ message: String) {
        addOutput("ℹ️  \(message)\n")
    }
    
    func addProgressMessage(_ message: String) {
        addOutput("⏳ \(message)\n")
    }
    
    /// Start live monitoring mode (like top/htop)
    func startLiveMode() {
        isLiveMode = true
        isRunning = true
        
        // Clear existing output
        clearOutput()
        
        // Add initial header
        addOutput("MultiPing Live Monitor - Starting...\n")
        addOutput("Press 'q' to quit, 'r' to refresh, 's' for stats\n")
        addOutput("=" + String(repeating: "=", count: 60) + "\n")
        
        // Start update timer
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateLiveDisplay()
        }
    }
    
    /// Stop live monitoring mode
    func stopLiveMode() {
        isLiveMode = false
        isRunning = false
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    /// Update the live display with current device data
    private func updateLiveDisplay() {
        guard isLiveMode && !isUpdating else { return }
        
        isUpdating = true
        defer { isUpdating = false }
        
        // Get live data from bridge
        let liveData = CLIDataBridge.shared.getFormattedDeviceData()
        
        // Clear and update output
        DispatchQueue.main.async {
            // Keep only the header lines and replace the data section
            let lines = self.output.components(separatedBy: .newlines)
            let headerLines = lines.prefix(4) // Keep first 4 lines (header)
            let newOutput = headerLines.joined(separator: "\n") + "\n" + liveData
            self.output = newOutput
        }
    }
    
    /// Setup live update notifications
    private func setupLiveUpdates() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("cliDataUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if self?.isLiveMode == true {
                self?.updateLiveDisplay()
            }
        }
    }
    
    deinit {
        updateTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Terminal Line Model
struct TerminalLine {
    let content: String
    let timestamp: Date
    
    var formattedContent: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "[\(formatter.string(from: timestamp))] \(content)"
    }
}

// MARK: - NSWindowDelegate Methods
extension CLITerminalWindowController {
    func windowWillClose(_ notification: Notification) {
        // Notify the EnhancedCLIRunner that the window is closing
        NotificationCenter.default.post(
            name: NSNotification.Name("CLITerminalWindowWillClose"),
            object: self
        )
    }
}
