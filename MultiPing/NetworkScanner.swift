import Foundation
import Network
import Combine

// Discovered device model
struct DiscoveredDevice: Identifiable {
    let id = UUID()
    let ipAddress: String
    let hostname: String
    let isReachable: Bool
}

// Network scanner for finding devices on local network
class NetworkScanner: ObservableObject {
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var isScanning = false
    
    private var scanTask: Task<Void, Never>?
    
    func startScanning() {
        guard !isScanning else { return }
        
        isScanning = true
        discoveredDevices.removeAll()
        
        scanTask = Task {
            await scanLocalNetwork()
        }
    }
    
    func stopScanning() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }
    
    private func scanLocalNetwork() async {
        // Get local IP and subnet
        guard let localIP = getLocalIPAddress() else {
            print("NetworkScanner: Could not determine local IP address")
            await MainActor.run { isScanning = false }
            return
        }
        
        print("NetworkScanner: Starting scan from local IP: \(localIP)")
        
        // Extract network portion (assuming /24 subnet)
        let ipComponents = localIP.components(separatedBy: ".")
        guard ipComponents.count == 4 else {
            await MainActor.run { isScanning = false }
            return
        }
        
        let networkBase = "\(ipComponents[0]).\(ipComponents[1]).\(ipComponents[2])"
        
        // Scan common IP ranges
        let rangesToScan = [
            1...10,    // Common static IPs
            100...110, // Common DHCP ranges
            200...254  // Higher DHCP ranges
        ]
        
        for range in rangesToScan {
            guard !Task.isCancelled else { break }
            
            await withTaskGroup(of: Void.self) { group in
                for i in range {
                    guard !Task.isCancelled else { break }
                    
                    group.addTask {
                        let ip = "\(networkBase).\(i)"
                        if await self.pingHost(ip) {
                            let hostname = await self.getHostname(for: ip)
                            let device = DiscoveredDevice(
                                ipAddress: ip,
                                hostname: hostname,
                                isReachable: true
                            )
                            
                            await MainActor.run {
                                self.discoveredDevices.append(device)
                            }
                        }
                    }
                }
            }
            
            // Small delay between ranges
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        await MainActor.run {
            isScanning = false
            print("NetworkScanner: Scan complete. Found \(discoveredDevices.count) devices")
        }
    }
    
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // Check for IPv4 or IPv6 interface
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                
                // Check interface name
                let name = String(cString: interface.ifa_name)
                if name == "en0" { // WiFi
                    
                    // Convert interface address to a human readable string
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
        return address
    }
    
    private func pingHost(_ ip: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let task = Process()
            task.launchPath = "/sbin/ping"
            task.arguments = ["-c", "1", "-W", "1000", ip] // 1 ping, 1 second timeout
            task.standardOutput = Pipe()
            task.standardError = Pipe()
            
            task.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus == 0)
            }
            
            do {
                try task.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
    
    private func getHostname(for ip: String) async -> String {
        return await withCheckedContinuation { continuation in
            let task = Process()
            task.launchPath = "/usr/bin/nslookup"
            task.arguments = [ip]
            
            let output = Pipe()
            task.standardOutput = output
            task.standardError = Pipe()
            
            task.terminationHandler = { _ in
                let data = output.fileHandleForReading.readDataToEndOfFile()
                if let outputString = String(data: data, encoding: .utf8) {
                    // Parse nslookup output to extract hostname
                    let lines = outputString.components(separatedBy: .newlines)
                    for line in lines {
                        if line.contains("name = ") {
                            let components = line.components(separatedBy: "name = ")
                            if components.count > 1 {
                                let hostname = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                                continuation.resume(returning: String(hostname.dropLast(1))) // Remove trailing dot
                                return
                            }
                        }
                    }
                }
                continuation.resume(returning: "")
            }
            
            do {
                try task.run()
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
    
    deinit {
        stopScanning()
    }
}