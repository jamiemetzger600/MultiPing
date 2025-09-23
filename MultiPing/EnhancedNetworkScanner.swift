import Foundation
import Network
import Combine

// MARK: - Network Interface Model
struct NetworkInterface: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let ipAddress: String
    let subnetMask: String
    let networkAddress: String
    let subnetRange: String
    let isActive: Bool
    
    var displayName: String {
        return "\(name) (\(ipAddress))"
    }
    
    init(name: String, ipAddress: String, subnetMask: String, networkAddress: String, subnetRange: String, isActive: Bool = true) {
        self.id = UUID()
        self.name = name
        self.ipAddress = ipAddress
        self.subnetMask = subnetMask
        self.networkAddress = networkAddress
        self.subnetRange = subnetRange
        self.isActive = isActive
    }
}

// MARK: - Enhanced Network Scanner

@MainActor
class EnhancedNetworkScanner: ObservableObject {
    @Published var isScanning = false
    @Published var discoveredDevices: [NetworkDevice] = [] {
        didSet {
            saveScanResults()
        }
    }
    @Published var scanProgress: Double = 0.0
    @Published var currentScanIP: String? = nil
    @Published var availableInterfaces: [NetworkInterface] = []
    @Published var selectedInterface: NetworkInterface? = nil {
        didSet {
            // Auto-fill default range when interface is selected
            if selectedInterface != nil && customRangeStart.isEmpty && customRangeEnd.isEmpty {
                useDefaultRange()
            }
        }
    }
    @Published var customRangeStart: String = ""
    @Published var customRangeEnd: String = ""
    @Published var useCustomRange: Bool = false
    
    private var scanTask: Task<Void, Never>?
    private let scanResultsKey = "EnhancedNetworkScanner_SavedResults"
    
    // Enhanced vendor lookup with more comprehensive data (deduplicated)
    static let enhancedVendorLookup: [String: String] = [
        // Apple devices
        "001451": "Apple, Inc.", "0017F2": "Apple, Inc.", "0019E3": "Apple, Inc.", "001B63": "Apple, Inc.",
        "001EC2": "Apple, Inc.", "0021E9": "Apple, Inc.", "002312": "Apple, Inc.", "002332": "Apple, Inc.",
        "0025BC": "Apple, Inc.", "002608": "Apple, Inc.", "0026BB": "Apple, Inc.", "002713": "Apple, Inc.",
        "28E02C": "Apple, Inc.", "30F7C5": "Apple, Inc.", "3C2EFF": "Apple, Inc.", "40A6D9": "Apple, Inc.",
        "44D884": "Apple, Inc.", "50ED3C": "Apple, Inc.", "64B9E8": "Apple, Inc.", "68A86D": "Apple, Inc.",
        "6C3E6D": "Apple, Inc.", "70CD60": "Apple, Inc.", "78CA39": "Apple, Inc.", "7C6DF8": "Apple, Inc.",
        "ACDE48": "Apple, Inc.", "B827EB": "Apple, Inc.", "C8E0EB": "Apple, Inc.", "D8A25E": "Apple, Inc.",
        "C6B097": "Apple, Inc.", "04B4A6": "Apple, Inc.", "7C04D0": "Apple, Inc.",
        
        // Amazon devices
        "001FC6": "Amazon Technologies Inc.", "00FC58": "Amazon Technologies Inc.", "0C47C9": "Amazon Technologies Inc.",
        "107B44": "Amazon Technologies Inc.", "18B430": "Amazon Technologies Inc.", "1C994C": "Amazon Technologies Inc.",
        "2C5497": "Amazon Technologies Inc.", "341298": "Amazon Technologies Inc.", "3C28A6": "Amazon Technologies Inc.",
        "40B4CD": "Amazon Technologies Inc.", "44A42D": "Amazon Technologies Inc.", "50F5DA": "Amazon Technologies Inc.",
        "68DBF5": "Amazon Technologies Inc.", "6C5AB5": "Amazon Technologies Inc.", "78E103": "Amazon Technologies Inc.",
        "7C67A2": "Amazon Technologies Inc.", "84D6D0": "Amazon Technologies Inc.", "8C85C1": "Amazon Technologies Inc.",
        "A002DC": "Amazon Technologies Inc.", "A0D795": "Amazon Technologies Inc.", "B4E9B0": "Amazon Technologies Inc.",
        "C0A0BB": "Amazon Technologies Inc.", "D02544": "Amazon Technologies Inc.", "D8FBD6": "Amazon Technologies Inc.",
        "74E20C": "Amazon Technologies Inc.", "54E61B": "Amazon Technologies Inc.",
        
        // HP devices
        "001A4B": "HP Inc.", "001B78": "HP Inc.", "001D4F": "HP Inc.", "001E0B": "HP Inc.", "002264": "HP Inc.",
        "002445": "HP Inc.", "0022B0": "HP Inc.", "001F3A": "HP Inc.", "0022A4": "HP Inc.", "0023AE": "HP Inc.",
        "00E04C": "HP Inc.", "28C5C8": "HP Inc.", "2C44FD": "HP Inc.", "3C4A92": "HP Inc.", "3C52AE": "HP Inc.",
        
        // TP-Link devices
        "50C7BF": "TP-Link Systems Inc.", "C46E1F": "TP-Link Systems Inc.", "E894F6": "TP-Link Systems Inc.",
        "F4EC38": "TP-Link Systems Inc.", "00D0F7": "TP-Link Systems Inc.", "00B0C6": "TP-Link Systems Inc.",
        "001F33": "TP-Link Systems Inc.", "14CC20": "TP-Link Systems Inc.", "18A905": "TP-Link Systems Inc.",
        
        // Sonos devices
        "B8E937": "Sonos, Inc.", "94CE2C": "Sonos, Inc.", "7825AD": "Sonos, Inc.", "5CAAFD": "Sonos, Inc.",
        "001B66": "Sonos, Inc.", "7824AF": "Sonos, Inc.",
        
        // Wyze devices
        "2CAA8E": "Wyze Labs Inc", "7C78B2": "Wyze Labs Inc", "A0E4CB": "Wyze Labs Inc", "D03F27": "Wyze Labs Inc",
        
        // Brother devices
        "F889D2": "Brother Industries, Ltd.", "0012F0": "Brother Industries, Ltd.",
        
        // Chamberlain devices
        "CC6A10": "The Chamberlain Group, Inc",
        
        // Tonal devices
        "105917": "Tonal Systems, Inc.", "001E8C": "Tonal Systems, Inc.",
        
        // Smart Innovation devices
        "0417B6": "Smart Innovation LLC", "001A2F": "Smart Innovation LLC"
    ]
    
    // Device identification patterns
    static let deviceIdentificationPatterns: [String: String] = [
        // Apple devices
        "Apple, Inc.": "Apple Device",
        
        // Amazon devices
        "Amazon Technologies Inc.": "Amazon Device",
        
        // HP devices
        "HP Inc.": "HP Device",
        
        // Sonos devices
        "Sonos, Inc.": "Sonos Audio System",
        
        // Wyze devices
        "Wyze Labs Inc": "Wyze Smart Device",
        
        // Brother devices
        "Brother Industries, Ltd.": "Brother Printer",
        "CLOUD NETWORK TECHNOLOGY S": "Brother Printer",
        
        // Chamberlain devices
        "The Chamberlain Group, Inc": "Chamberlain Garage Door Opener",
        
        // Tonal devices
        "Tonal Systems, Inc.": "Tonal Fitness Equipment",
        
        // Smart Innovation devices
        "Smart Innovation LLC": "Smart Device"
    ]
    
    init() {
        // Load saved results when the scanner is initialized
        loadSavedResults()
        
        // Load network interfaces
        Task {
            await loadNetworkInterfaces()
        }
    }
    
    func startScan() {
        guard !isScanning, let interface = selectedInterface else { return }
        
        isScanning = true
        discoveredDevices.removeAll()
        scanProgress = 0.0
        currentScanIP = nil
        
        scanTask = Task {
            await performEnhancedScan(interface: interface)
            await MainActor.run {
                isScanning = false
                currentScanIP = nil
                print("Enhanced scan complete. Found \(discoveredDevices.count) devices.")
            }
        }
    }
    
    func refreshInterfaces() {
        Task {
            await loadNetworkInterfaces()
        }
    }
    
    func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        currentScanIP = nil
    }
    
    func clearResults() {
        discoveredDevices.removeAll()
        clearSavedResults()
    }
    
    /// Set default IP range based on the selected interface
    func useDefaultRange() {
        guard let interface = selectedInterface else { return }
        
        // Extract the network prefix (e.g., "10.10.0" from "10.10.0.65")
        let ipComponents = interface.ipAddress.components(separatedBy: ".")
        if ipComponents.count >= 3 {
            let networkPrefix = "\(ipComponents[0]).\(ipComponents[1]).\(ipComponents[2])"
            customRangeStart = "\(networkPrefix).1"
            customRangeEnd = "\(networkPrefix).254"
            useCustomRange = true
            print("Set default range: \(customRangeStart) to \(customRangeEnd)")
        }
    }
    
    private func performEnhancedScan(interface: NetworkInterface) async {
        print("Enhanced scanning network: \(interface.subnetRange) on interface \(interface.name)")
        
        // Determine IP range to scan
        let ipsToScan = useCustomRange ? generateCustomIPRange() : generateIPsToScan(for: interface)
        guard !ipsToScan.isEmpty else {
            print("No IPs to scan - invalid network configuration")
            return
        }
        
        let totalIPs = ipsToScan.count
        var scannedCount = 0
        
        print("Scanning \(totalIPs) IPs...")
        
        // Scan each IP with enhanced discovery
        await withTaskGroup(of: NetworkDevice?.self) { group in
            var activeTasks = 0
            let maxConcurrent = 100 // Higher concurrency for faster scanning
            
            for ip in ipsToScan {
                guard !Task.isCancelled else { break }
                
                // Limit concurrent tasks
                if activeTasks >= maxConcurrent {
                    if let device = await group.next() {
                        if let device = device {
                            await MainActor.run {
                                discoveredDevices.append(device)
                                discoveredDevices.sort { $0.ipAddress.localizedStandardCompare($1.ipAddress) == .orderedAscending }
                            }
                        }
                        activeTasks -= 1
                        scannedCount += 1
                        await MainActor.run {
                            scanProgress = Double(scannedCount) / Double(totalIPs)
                        }
                    }
                }
                
                group.addTask {
                    await self.scanIPEnhanced(ip)
                }
                activeTasks += 1
            }
            
            // Process remaining tasks
            while let device = await group.next() {
                if let device = device {
                    await MainActor.run {
                        discoveredDevices.append(device)
                        discoveredDevices.sort { $0.ipAddress.localizedStandardCompare($1.ipAddress) == .orderedAscending }
                    }
                }
                scannedCount += 1
                await MainActor.run {
                    scanProgress = Double(scannedCount) / Double(totalIPs)
                }
            }
        }
        
        await MainActor.run {
            isScanning = false
            currentScanIP = nil
            print("Enhanced scan complete. Found \(discoveredDevices.count) devices.")
        }
    }
    
    private func scanIPEnhanced(_ ip: String) async -> NetworkDevice? {
        guard !Task.isCancelled else { return nil }
        
        await MainActor.run { currentScanIP = ip }
        
        // Enhanced ping test with better timeout
        let isReachable = await pingIPEnhanced(ip)
        guard isReachable else { return nil }
        
        // Gather comprehensive device information
        async let hostname = getHostnameEnhanced(ip)
        async let macAddress = getMACAddressEnhanced(ip)
        async let dnsName = getDNSName(ip)
        async let mdnsName = getmDNSName(ip)
        async let smbName = getSMBName(ip)
        
        let results = await (hostname, macAddress, dnsName, mdnsName, smbName)
        
        let vendor = getVendorEnhanced(from: results.1)
        let identification = getDeviceIdentification(vendor: vendor, hostname: results.0, macAddress: results.1)
        
        return NetworkDevice(
            ipAddress: ip,
            macAddress: results.1,
            hostname: results.0,
            vendor: vendor,
            identification: identification,
            dnsName: results.2,
            mdnsName: results.3,
            smbName: results.4,
            isReachable: true
        )
    }
    
    private func pingIPEnhanced(_ ip: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.launchPath = "/sbin/ping"
            process.arguments = ["-c", "1", "-W", "2000", "-t", "2", ip] // 2 second timeout
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            
            process.terminationHandler = { process in
                let success = process.terminationStatus == 0
                if success {
                    print("✓ Found device at \(ip)")
                }
                continuation.resume(returning: success)
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
    
    private func getHostnameEnhanced(_ ip: String) async -> String {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.launchPath = "/usr/bin/nslookup"
            process.arguments = [ip]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    // Parse hostname from nslookup output
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines {
                        if line.contains("name =") {
                            let parts = line.components(separatedBy: "name =")
                            if parts.count > 1 {
                                let hostname = parts[1].trimmingCharacters(in: .whitespaces)
                                let shortName = hostname.components(separatedBy: ".").first ?? ""
                                if !shortName.isEmpty && !shortName.allSatisfy({ $0.isNumber }) {
                                    continuation.resume(returning: shortName)
                                    return
                                }
                            }
                        }
                    }
                }
                continuation.resume(returning: "")
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
    
    private func getMACAddressEnhanced(_ ip: String) async -> String {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.launchPath = "/usr/sbin/arp"
            process.arguments = ["-n", ip]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    // Parse MAC from arp output
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines {
                        if line.contains(ip) && !line.contains("incomplete") {
                            let parts = line.components(separatedBy: .whitespaces)
                            for part in parts {
                                if part.contains(":") && part.count >= 17 {
                                    continuation.resume(returning: part)
                                    return
                                }
                            }
                        }
                    }
                }
                continuation.resume(returning: "")
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
    
    private func getDNSName(_ ip: String) async -> String {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.launchPath = "/usr/bin/dig"
            process.arguments = ["+short", "-x", ip]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let hostname = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !hostname.isEmpty && !hostname.hasSuffix(".in-addr.arpa.") {
                        continuation.resume(returning: hostname.replacingOccurrences(of: ".", with: ""))
                    } else {
                        continuation.resume(returning: "")
                    }
                } else {
                    continuation.resume(returning: "")
                }
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
    
    private func getmDNSName(_ ip: String) async -> String {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.launchPath = "/usr/bin/dns-sd"
            process.arguments = ["-B", "_services._dns-sd._udp", "local"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            
            // Kill the process after a short time as it's continuous
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                if process.isRunning {
                    process.terminate()
                }
            }
            
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    // Parse mDNS services (simplified)
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines {
                        if line.contains(ip) {
                            let parts = line.components(separatedBy: "\t")
                            if parts.count > 0 {
                                continuation.resume(returning: parts[0])
                                return
                            }
                        }
                    }
                }
                continuation.resume(returning: "")
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
    
    private func getSMBName(_ ip: String) async -> String {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.launchPath = "/usr/bin/smbclient"
            process.arguments = ["-L", ip, "-N"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    // Parse SMB shares (simplified)
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines {
                        if line.contains("Server") && line.contains("Comment") {
                            continue
                        }
                        if line.contains("\t") && !line.contains("IPC$") && !line.contains("print$") {
                            let parts = line.components(separatedBy: "\t")
                            if parts.count > 0 && !parts[0].trimmingCharacters(in: .whitespaces).isEmpty {
                                continuation.resume(returning: parts[0].trimmingCharacters(in: .whitespaces))
                                return
                            }
                        }
                    }
                }
                continuation.resume(returning: "")
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
    
    private func getVendorEnhanced(from macAddress: String) -> String {
        guard macAddress.count >= 8 else { return "" }
        
        let oui = String(macAddress.replacingOccurrences(of: ":", with: "").prefix(6)).uppercased()
        
        return Self.enhancedVendorLookup[oui] ?? ""
    }
    
    private func getDeviceIdentification(vendor: String, hostname: String, macAddress: String) -> String {
        // Try to get specific device identification
        if let identification = Self.deviceIdentificationPatterns[vendor] {
            return identification
        }
        
        // Fallback to hostname or generic identification
        if !hostname.isEmpty && hostname != "Unknown" {
            return hostname
        }
        
        return vendor.isEmpty ? "Unknown Device" : "\(vendor) Device"
    }
    
    private func generateCustomIPRange() -> [String] {
        let startComponents = customRangeStart.components(separatedBy: ".")
        let endComponents = customRangeEnd.components(separatedBy: ".")
        
        guard startComponents.count == 4 && endComponents.count == 4 else { return [] }
        
        var ips: [String] = []
        
        // Simple range generation (assuming same network)
        if startComponents[0] == endComponents[0] && startComponents[1] == endComponents[1] && startComponents[2] == endComponents[2] {
            let startHost = Int(startComponents[3]) ?? 1
            let endHost = Int(endComponents[3]) ?? 254
            let networkBase = "\(startComponents[0]).\(startComponents[1]).\(startComponents[2])"
            
            for host in startHost...endHost {
                ips.append("\(networkBase).\(host)")
            }
        }
        
        return ips
    }
    
    private func loadNetworkInterfaces() async {
        await withCheckedContinuation { continuation in
            Task.detached {
                let interfaces = await self.getNetworkInterfaces()
                await MainActor.run {
                    self.availableInterfaces = interfaces
                    // Auto-select the first active interface if none selected
                    if self.selectedInterface == nil {
                        self.selectedInterface = interfaces.first { $0.isActive }
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    private func getNetworkInterfaces() async -> [NetworkInterface] {
        var interfaces: [NetworkInterface] = []
        
        let process = Process()
        process.launchPath = "/sbin/ifconfig"
        process.arguments = []
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            await withCheckedContinuation { continuation in
                process.terminationHandler = { _ in
                    continuation.resume()
                }
            }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                interfaces = parseIfconfigOutput(output)
            }
        } catch {
            print("Error getting network interfaces: \(error)")
        }
        
        return interfaces
    }
    
    private func parseIfconfigOutput(_ output: String) -> [NetworkInterface] {
        var interfaces: [NetworkInterface] = []
        let lines = output.components(separatedBy: .newlines)
        
        var currentInterface: String?
        var currentIP: String?
        var currentMask: String?
        var isActive = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // New interface line (starts at beginning of line)
            if !line.hasPrefix(" ") && !line.hasPrefix("\t") && line.contains(":") {
                // Save previous interface if we have one
                if let name = currentInterface, let ip = currentIP, let mask = currentMask {
                    if let networkAddr = calculateNetworkAddress(ip: ip, mask: mask) {
                        let subnetRange = "\(networkAddr)/\(mask)"
                        let interface = NetworkInterface(
                            name: name,
                            ipAddress: ip,
                            subnetMask: mask,
                            networkAddress: networkAddr,
                            subnetRange: subnetRange,
                            isActive: isActive
                        )
                        interfaces.append(interface)
                    }
                }
                
                // Start new interface
                let parts = trimmedLine.components(separatedBy: ":")
                currentInterface = parts.first
                currentIP = nil
                currentMask = nil
                isActive = trimmedLine.contains("UP") && !trimmedLine.contains("LOOPBACK")
            }
            // Look for inet line
            else if trimmedLine.contains("inet ") && !trimmedLine.contains("inet6") {
                let parts = trimmedLine.components(separatedBy: .whitespaces)
                for i in 0..<parts.count {
                    if parts[i] == "inet" && i + 1 < parts.count {
                        currentIP = parts[i + 1]
                    }
                    if parts[i] == "netmask" && i + 1 < parts.count {
                        currentMask = parts[i + 1]
                    }
                }
            }
        }
        
        // Don't forget the last interface
        if let name = currentInterface, let ip = currentIP, let mask = currentMask {
            if let networkAddr = calculateNetworkAddress(ip: ip, mask: mask) {
                let subnetRange = "\(networkAddr)/\(mask)"
                let interface = NetworkInterface(
                    name: name,
                    ipAddress: ip,
                    subnetMask: mask,
                    networkAddress: networkAddr,
                    subnetRange: subnetRange,
                    isActive: isActive
                )
                interfaces.append(interface)
            }
        }
        
        // Filter out loopback and inactive interfaces
        return interfaces.filter { !$0.name.hasPrefix("lo") && $0.isActive && $0.ipAddress != "127.0.0.1" }
    }
    
    private func calculateNetworkAddress(ip: String, mask: String) -> String? {
        let ipComponents = ip.components(separatedBy: ".")
        guard ipComponents.count == 4 else { return nil }
        
        // Convert hex mask to decimal if needed
        let maskComponents: [String]
        if mask.hasPrefix("0x") {
            // Convert hex mask to dotted decimal
            let hexMask = String(mask.dropFirst(2))
            guard let maskInt = UInt32(hexMask, radix: 16) else { return nil }
            
            let byte1 = (maskInt >> 24) & 0xFF
            let byte2 = (maskInt >> 16) & 0xFF
            let byte3 = (maskInt >> 8) & 0xFF
            let byte4 = maskInt & 0xFF
            
            maskComponents = ["\(byte1)", "\(byte2)", "\(byte3)", "\(byte4)"]
        } else {
            maskComponents = mask.components(separatedBy: ".")
            guard maskComponents.count == 4 else { return nil }
        }
        
        var networkComponents: [String] = []
        for i in 0..<4 {
            guard let ipByte = UInt8(ipComponents[i]),
                  let maskByte = UInt8(maskComponents[i]) else { return nil }
            
            let networkByte = ipByte & maskByte
            networkComponents.append("\(networkByte)")
        }
        
        return networkComponents.joined(separator: ".")
    }
    
    private func generateIPsToScan(for interface: NetworkInterface) -> [String] {
        let networkComponents = interface.networkAddress.components(separatedBy: ".")
        guard networkComponents.count == 4 else { 
            print("Invalid network address: \(interface.networkAddress)")
            return [] 
        }
        
        // Convert subnet mask to dotted decimal if it's in hex format
        let decimalMask = convertMaskToDecimal(interface.subnetMask)
        print("Original mask: \(interface.subnetMask), Decimal mask: \(decimalMask)")
        
        // Determine subnet size and generate IPs accordingly
        if decimalMask == "255.255.255.0" { // /24
            let networkBase = "\(networkComponents[0]).\(networkComponents[1]).\(networkComponents[2])"
            print("Scanning /24 network: \(networkBase).1-254")
            return (1...254).map { "\(networkBase).\($0)" }
        }
        else if decimalMask == "255.255.252.0" { // /22 (common in corporate networks)
            let networkBase = "\(networkComponents[0]).\(networkComponents[1])"
            let thirdOctet = Int(networkComponents[2]) ?? 0
            let baseThird = (thirdOctet / 4) * 4 // Round down to nearest multiple of 4
            
            var ips: [String] = []
            // Scan full /22 range (1024 IPs total)
            for subnet in baseThird..<(baseThird + 4) {
                for host in 1...254 {
                    ips.append("\(networkBase).\(subnet).\(host)")
                }
            }
            print("Scanning /22 network: \(ips.count) IPs (full range)")
            return ips
        }
        else if decimalMask == "255.255.0.0" { // /16
            let networkBase = "\(networkComponents[0]).\(networkComponents[1])"
            var ips: [String] = []
            // Scan common subnets in /16 range
            for subnet in [0, 1, 10, 100, 168, 254] {
                for host in [1, 2, 10, 100, 254] {
                    ips.append("\(networkBase).\(subnet).\(host)")
                }
            }
            print("Scanning /16 network: \(ips.count) selected IPs")
            return ips
        }
        else {
            // Default fallback - assume /24
            let networkBase = "\(networkComponents[0]).\(networkComponents[1]).\(networkComponents[2])"
            print("Unknown mask format, defaulting to /24: \(networkBase).1-254")
            return (1...254).map { "\(networkBase).\($0)" }
        }
    }
    
    private func convertMaskToDecimal(_ mask: String) -> String {
        if mask.hasPrefix("0x") {
            // Convert hex mask to dotted decimal
            let hexMask = String(mask.dropFirst(2))
            guard let maskInt = UInt32(hexMask, radix: 16) else { return mask }
            
            let byte1 = (maskInt >> 24) & 0xFF
            let byte2 = (maskInt >> 16) & 0xFF
            let byte3 = (maskInt >> 8) & 0xFF
            let byte4 = maskInt & 0xFF
            
            return "\(byte1).\(byte2).\(byte3).\(byte4)"
        }
        return mask // Already in decimal format
    }
    
    // MARK: - Persistence Methods
    
    /// Load saved scan results from UserDefaults
    func loadSavedResults() {
        guard let data = UserDefaults.standard.data(forKey: scanResultsKey),
              let savedDevices = try? JSONDecoder().decode([NetworkDevice].self, from: data) else {
            print("No saved scan results found or failed to decode")
            return
        }
        
        print("Loading \(savedDevices.count) saved scan results")
        discoveredDevices = savedDevices
    }
    
    /// Save current scan results to UserDefaults
    private func saveScanResults() {
        do {
            let data = try JSONEncoder().encode(discoveredDevices)
            UserDefaults.standard.set(data, forKey: scanResultsKey)
            print("Saved \(discoveredDevices.count) scan results to UserDefaults")
        } catch {
            print("Failed to save scan results: \(error)")
        }
    }
    
    /// Clear saved scan results from UserDefaults
    private func clearSavedResults() {
        UserDefaults.standard.removeObject(forKey: scanResultsKey)
        print("Cleared saved scan results from UserDefaults")
    }
}
