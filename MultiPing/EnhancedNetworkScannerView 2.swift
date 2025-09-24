import SwiftUI

struct EnhancedNetworkScannerView: View {
    @StateObject private var scanner = EnhancedNetworkScanner()
    @StateObject private var pingManager = PingManager.shared
    @State private var selectedDevices = Set<UUID>()
    @State private var searchText = ""
    @State private var showConfig = false
    @State private var showAddDevicesAlert = false
    @State private var addedDeviceCount = 0
    
    // Sorting state
    @State private var sortColumn: SortColumn = .ipAddress
    @State private var sortOrder: SortOrder = .ascending
    
    // Window sizing
    @State private var windowSize: CGSize = CGSize(width: 800, height: 600)
    
    enum SortColumn: String, CaseIterable {
        case ipAddress = "IPv4 address"
        case macAddress = "MAC address"
        case hostname = "Hostname"
        case ping = "Ping"
        case vendor = "Vendor"
        case identification = "Identification"
        case dnsName = "DNS Name"
        case mdnsName = "mDNS Name"
        case smbName = "SMB Name"
    }
    
    enum SortOrder {
        case ascending
        case descending
        
        var toggle: SortOrder {
            switch self {
            case .ascending: return .descending
            case .descending: return .ascending
            }
        }
    }
    
    var filteredDevices: [NetworkDevice] {
        let devices = if searchText.isEmpty {
            scanner.discoveredDevices
        } else {
            scanner.discoveredDevices.filter { device in
                device.ipAddress.localizedCaseInsensitiveContains(searchText) ||
                device.hostname.localizedCaseInsensitiveContains(searchText) ||
                device.macAddress.localizedCaseInsensitiveContains(searchText) ||
                device.vendor.localizedCaseInsensitiveContains(searchText) ||
                device.identification.localizedCaseInsensitiveContains(searchText) ||
                device.dnsName.localizedCaseInsensitiveContains(searchText) ||
                device.mdnsName.localizedCaseInsensitiveContains(searchText) ||
                device.smbName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return sortedDevices(devices)
    }
    
    private func sortedDevices(_ devices: [NetworkDevice]) -> [NetworkDevice] {
        return devices.sorted { device1, device2 in
            let result: ComparisonResult
            
            switch sortColumn {
            case .ipAddress:
                result = compareIPAddresses(device1.ipAddress, device2.ipAddress)
            case .macAddress:
                result = device1.macAddress.localizedCaseInsensitiveCompare(device2.macAddress)
            case .hostname:
                result = device1.hostname.localizedCaseInsensitiveCompare(device2.hostname)
            case .ping:
                result = device1.isReachable == device2.isReachable ? .orderedSame : 
                        (device1.isReachable ? .orderedDescending : .orderedAscending)
            case .vendor:
                result = device1.vendor.localizedCaseInsensitiveCompare(device2.vendor)
            case .identification:
                result = device1.identification.localizedCaseInsensitiveCompare(device2.identification)
            case .dnsName:
                result = device1.dnsName.localizedCaseInsensitiveCompare(device2.dnsName)
            case .mdnsName:
                result = device1.mdnsName.localizedCaseInsensitiveCompare(device2.mdnsName)
            case .smbName:
                result = device1.smbName.localizedCaseInsensitiveCompare(device2.smbName)
            }
            
            return sortOrder == .ascending ? result == .orderedAscending : result == .orderedDescending
        }
    }
    
    private func compareIPAddresses(_ ip1: String, _ ip2: String) -> ComparisonResult {
        let components1 = ip1.components(separatedBy: ".").compactMap { Int($0) }
        let components2 = ip2.components(separatedBy: ".").compactMap { Int($0) }
        
        guard components1.count == 4 && components2.count == 4 else {
            return ip1.localizedCaseInsensitiveCompare(ip2)
        }
        
        for (c1, c2) in zip(components1, components2) {
            if c1 < c2 { return .orderedAscending }
            if c1 > c2 { return .orderedDescending }
        }
        
        return .orderedSame
    }
    
    private func handleColumnClick(_ column: SortColumn) {
        if sortColumn == column {
            sortOrder = sortOrder.toggle
        } else {
            sortColumn = column
            sortOrder = .ascending
        }
    }
    
    private func sortIndicator(for column: SortColumn) -> String {
        guard sortColumn == column else { return "" }
        return sortOrder == .ascending ? " ▲" : " ▼"
    }
    
    // Check if columns have data to determine visibility
    var hasDNSData: Bool {
        filteredDevices.contains { !$0.dnsName.isEmpty }
    }
    
    var hasMDNSData: Bool {
        filteredDevices.contains { !$0.mdnsName.isEmpty }
    }
    
    var hasSMBData: Bool {
        filteredDevices.contains { !$0.smbName.isEmpty }
    }
    
    // Calculate optimal window size based on content
    var optimalWindowSize: CGSize {
        let deviceCount = filteredDevices.count
        let baseHeight: CGFloat = 200 // Toolbar + headers + padding
        let rowHeight: CGFloat = 25
        let maxHeight: CGFloat = 600
        
        // Calculate width based on visible columns only
        var totalWidth: CGFloat = 150 // Base padding and margins
        totalWidth += 120 // IPv4 address
        totalWidth += 140 // MAC address
        totalWidth += 150 // Hostname
        totalWidth += 50  // Ping
        totalWidth += 120 // Vendor
        totalWidth += 150 // Identification
        
        // Only add width for columns that actually have data
        if hasDNSData { totalWidth += 120 }
        if hasMDNSData { totalWidth += 120 }
        if hasSMBData { totalWidth += 120 }
        
        let minWidth: CGFloat = 700
        let maxWidth: CGFloat = 1000
        
        let width = max(minWidth, min(totalWidth, maxWidth))
        let height = max(400, min(baseHeight + (CGFloat(deviceCount) * rowHeight), maxHeight))
        
        return CGSize(width: width, height: height)
    }
    
    var scanRangeText: String {
        if scanner.useCustomRange && !scanner.customRangeStart.isEmpty && !scanner.customRangeEnd.isEmpty {
            return "Scan from \(scanner.customRangeStart) to \(scanner.customRangeEnd)"
        } else if let interface = scanner.selectedInterface {
            return "Scan from \(interface.networkAddress)/\(interface.subnetMask)"
        } else {
            return "No network selected"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button("Start LanScan") {
                    scanner.startScan()
                }
                .buttonStyle(.borderedProminent)
                .disabled(scanner.isScanning || scanner.selectedInterface == nil)
                
                Button("Edit Hostname") {
                    // TODO: Implement hostname editing
                }
                .disabled(selectedDevices.isEmpty)
                
                if !scanner.discoveredDevices.isEmpty && !scanner.isScanning {
                    Button("Add Selected to Monitor") {
                        addSelectedDevices()
                    }
                    .disabled(selectedDevices.isEmpty)
                }
                
                Button("Clear Results") {
                    scanner.clearResults()
                    selectedDevices.removeAll()
                }
                .disabled(scanner.discoveredDevices.isEmpty)
                
                Button("Config") {
                    showConfig.toggle()
                }
                
                Spacer()
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search devices...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(6)
                .frame(width: 200)
                
                Button("Details") {
                    // TODO: Implement details view
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            
            // Scan range indicator
            HStack {
                Text(scanRangeText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Progress indicator
            if scanner.isScanning {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Scanning...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if let currentIP = scanner.currentScanIP {
                            Text("Current: \(currentIP)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("\(Int(scanner.scanProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: scanner.scanProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            // Results summary
            if !scanner.discoveredDevices.isEmpty {
                HStack {
                    Text("\(scanner.discoveredDevices.count) devices found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("Results persist between sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
            
            // Results table
            if filteredDevices.isEmpty && !scanner.isScanning {
                VStack {
                    Spacer()
                    Text("No devices found. Click 'Start LanScan' to discover devices on your network.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                // Use native table with proper headers - always include all columns but hide empty ones
                Table(filteredDevices, selection: $selectedDevices) {
                    TableColumn("IPv4 address\(sortIndicator(for: .ipAddress))") { (device: NetworkDevice) in
                        Text(device.ipAddress)
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 120, max: 140)
                    
                    TableColumn("MAC address\(sortIndicator(for: .macAddress))") { (device: NetworkDevice) in
                        Text(device.macAddress)
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: 140, max: 160)
                    
                    TableColumn("Hostname\(sortIndicator(for: .hostname))") { (device: NetworkDevice) in
                        Text(device.hostname)
                    }
                    .width(min: 150, max: 180)
                    
                    TableColumn("Ping\(sortIndicator(for: .ping))") { (device: NetworkDevice) in
                        Circle()
                            .fill(device.pingStatus == .reachable ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                    }
                    .width(min: 50, max: 60)
                    
                    TableColumn("Vendor\(sortIndicator(for: .vendor))") { (device: NetworkDevice) in
                        Text(device.vendor)
                    }
                    .width(min: 120, max: 160)
                    
                    TableColumn("Identification\(sortIndicator(for: .identification))") { (device: NetworkDevice) in
                        Text(device.identification)
                    }
                    .width(min: 150, max: 200)
                    
                    // Always include DNS Name column but hide if no data
                    TableColumn("DNS Name\(sortIndicator(for: .dnsName))") { (device: NetworkDevice) in
                        Text(hasDNSData ? device.dnsName : "")
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: hasDNSData ? 120 : 0, max: hasDNSData ? 160 : 0)
                    
                    // Always include mDNS Name column but hide if no data
                    TableColumn("mDNS Name\(sortIndicator(for: .mdnsName))") { (device: NetworkDevice) in
                        Text(hasMDNSData ? device.mdnsName : "")
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: hasMDNSData ? 120 : 0, max: hasMDNSData ? 160 : 0)
                    
                    // Always include SMB Name column but hide if no data
                    TableColumn("SMB Name\(sortIndicator(for: .smbName))") { (device: NetworkDevice) in
                        Text(hasSMBData ? device.smbName : "")
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: hasSMBData ? 120 : 0, max: hasSMBData ? 160 : 0)
                }
                .tableStyle(.bordered(alternatesRowBackgrounds: true))
            }
        }
        .frame(
            minWidth: optimalWindowSize.width,
            maxWidth: optimalWindowSize.width,
            minHeight: optimalWindowSize.height,
            maxHeight: optimalWindowSize.height
        )
        .onAppear {
            // Set initial window size
            windowSize = optimalWindowSize
        }
        .onChange(of: filteredDevices.count) { _ in
            // Auto-resize when device count changes
            withAnimation(.easeInOut(duration: 0.3)) {
                windowSize = optimalWindowSize
            }
        }
        .onChange(of: hasDNSData) { _ in
            // Auto-resize when column visibility changes
            withAnimation(.easeInOut(duration: 0.3)) {
                windowSize = optimalWindowSize
            }
        }
        .onChange(of: hasMDNSData) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                windowSize = optimalWindowSize
            }
        }
        .onChange(of: hasSMBData) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                windowSize = optimalWindowSize
            }
        }
        .sheet(isPresented: $showConfig) {
            NetworkConfigView(scanner: scanner)
        }
        .alert("Devices Added", isPresented: $showAddDevicesAlert) {
            Button("OK") { }
        } message: {
            Text("Successfully added \(addedDeviceCount) device(s) to monitoring.")
        }
    }
    
    private func addSelectedDevices() {
        guard !selectedDevices.isEmpty else { return }
        
        var addedCount = 0
        let selectedNetworkDevices = scanner.discoveredDevices.filter { selectedDevices.contains($0.id) }
        
        print("Adding \(selectedNetworkDevices.count) selected devices to monitor...")
        
        for networkDevice in selectedNetworkDevices {
            // Validate the network device before converting
            guard !networkDevice.ipAddress.isEmpty else {
                print("Skipping device with empty IP address")
                continue
            }
            
            let device = networkDevice.toDevice()
            
            // Double-check the converted device
            guard !device.ipAddress.isEmpty && device.ipAddress != "0.0.0.0" else {
                print("Skipping device with invalid IP address: \(device.ipAddress)")
                continue
            }
            
            if pingManager.addDevice(device) {
                addedCount += 1
                print("Successfully added device: \(device.name) - \(device.ipAddress)")
            } else {
                print("Failed to add device: \(device.name) - \(device.ipAddress)")
            }
        }
        
        addedDeviceCount = addedCount
        selectedDevices.removeAll()
        
        print("Added \(addedCount) devices to monitoring")
        
        if addedCount > 0 {
            showAddDevicesAlert = true
        }
    }
}

// MARK: - Network Configuration View

struct NetworkConfigView: View {
    @ObservedObject var scanner: EnhancedNetworkScanner
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Network Configuration")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
            }
            
            // Simplified single panel layout
            VStack(alignment: .leading, spacing: 16) {
                Text("Selected Interface")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Picker("Interface", selection: $scanner.selectedInterface) {
                            ForEach(scanner.availableInterfaces, id: \.id) { interface in
                                Text(interface.displayName)
                                    .tag(interface as NetworkInterface?)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Button("Refresh") {
                            scanner.refreshInterfaces()
                        }
                        .font(.caption)
                    }
                    
                    if let selectedInterface = scanner.selectedInterface {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Name: \(selectedInterface.name)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("IP / Mask: \(selectedInterface.ipAddress) / \(selectedInterface.subnetMask)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Network: \(selectedInterface.networkAddress)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Divider()
                
                Text("Scan Range")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("IP addresses to scan:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("From:")
                        TextField("Start IP", text: $scanner.customRangeStart)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                        
                        Text("To:")
                        TextField("End IP", text: $scanner.customRangeEnd)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                    
                    Button("Use Default Range") {
                        scanner.useDefaultRange()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            HStack {
                Button("Scan") {
                    scanner.startScan()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(scanner.selectedInterface == nil)
                
                Button("Close") {
                    dismiss()
                }
            }
        }
        .padding()
        .frame(width: 600, height: 400)
    }
    
    private func getMACAddress(for interface: String) -> String {
        // TODO: Implement MAC address lookup for interface
        return "Unknown"
    }
    
    private func getGateway(for interface: String) -> String {
        // TODO: Implement gateway lookup for interface
        return "Unknown"
    }
}

#Preview {
    EnhancedNetworkScannerView()
}
