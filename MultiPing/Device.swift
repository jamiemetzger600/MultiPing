//
//  Device.swift
//  MultiPing
//
//  Created by Jamie Metzger on 4/6/25.
//


import Foundation

struct Device: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var ipAddress: String
    var note: String?
    var isReachable: Bool = false
    var lastLatency: Double? = nil  // Last ping latency in milliseconds
    var lastPacketLoss: Double? = nil  // Last packet loss percentage
    var lastPingTime: Date? = nil  // When the last ping was performed

    init(id: UUID = UUID(), name: String, ipAddress: String, note: String? = nil) {
        self.id = id
        self.name = name
        self.ipAddress = ipAddress
        self.note = note
    }
}

// MARK: - Enhanced Network Device Model for Scanner

struct NetworkDevice: Identifiable, Codable, Hashable {
    let id: UUID
    let ipAddress: String
    let macAddress: String
    let hostname: String
    let vendor: String
    let identification: String
    let dnsName: String
    let mdnsName: String
    let smbName: String
    let isReachable: Bool
    let pingStatus: PingStatus
    
    enum PingStatus: String, Codable, CaseIterable {
        case reachable = "reachable"
        case unreachable = "unreachable"
        case unknown = "unknown"
        
        var color: String {
            switch self {
            case .reachable: return "green"
            case .unreachable: return "red"
            case .unknown: return "gray"
            }
        }
    }
    
    init(ipAddress: String, macAddress: String = "", hostname: String = "", vendor: String = "", 
         identification: String = "", dnsName: String = "", mdnsName: String = "", smbName: String = "", 
         isReachable: Bool = false) {
        self.id = UUID()
        self.ipAddress = ipAddress
        self.macAddress = macAddress.isEmpty ? "Unknown" : macAddress
        self.hostname = hostname.isEmpty ? "Unknown" : hostname
        self.vendor = vendor.isEmpty ? "Unknown" : vendor
        self.identification = identification.isEmpty ? "Unknown" : identification
        self.dnsName = dnsName.isEmpty ? "" : dnsName
        self.mdnsName = mdnsName.isEmpty ? "" : mdnsName
        self.smbName = smbName.isEmpty ? "" : smbName
        self.isReachable = isReachable
        self.pingStatus = isReachable ? .reachable : .unreachable
    }
    
    // Convert to basic Device for integration with existing system
    func toDevice() -> Device {
        // Ensure we have valid data to prevent crashes
        let safeHostname = hostname.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeIdentification = identification.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeVendor = vendor.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeIpAddress = ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeMacAddress = macAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create a safe display name
        let displayName: String
        if !safeHostname.isEmpty && safeHostname != "Unknown" {
            displayName = safeHostname
        } else if !safeIdentification.isEmpty && safeIdentification != "Unknown" {
            displayName = safeIdentification
        } else if !safeVendor.isEmpty && safeVendor != "Unknown" {
            displayName = "\(safeVendor) Device"
        } else {
            displayName = "Network Device"
        }
        
        // Create a safe note
        let note = "Discovered: \(safeVendor.isEmpty ? "Unknown" : safeVendor) - \(safeMacAddress.isEmpty ? "Unknown" : safeMacAddress)"
        
        return Device(
            name: displayName,
            ipAddress: safeIpAddress.isEmpty ? "0.0.0.0" : safeIpAddress,
            note: note
        )
    }
}
