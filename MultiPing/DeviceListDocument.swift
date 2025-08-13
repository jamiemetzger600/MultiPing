import Foundation
import UniformTypeIdentifiers
import SwiftUI

// Missing DeviceListDocument class
struct DeviceListDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    
    var devices: [Device]
    
    init(devices: [Device] = []) {
        self.devices = devices
    }
    
    init(configuration: ReadConfiguration) throws {
        devices = []
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let csv = devices.map { device in
            let note = device.note?.replacingOccurrences(of: ",", with: ";") ?? ""
            return "\(device.name),\(device.ipAddress),\(note)"
        }.joined(separator: "\n")
        
        let data = Data(csv.utf8)
        return .init(regularFileWithContents: data)
    }
}