import Foundation
import UniformTypeIdentifiers
import SwiftUI

// CSV Document for CSV export
struct DeviceListDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    static var writableContentTypes: [UTType] { [.commaSeparatedText] }
    
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

// TXT Document for TXT export
struct DeviceListTxtDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    static var writableContentTypes: [UTType] { [.plainText] }
    
    var devices: [Device]
    
    init(devices: [Device] = []) {
        self.devices = devices
    }
    
    init(configuration: ReadConfiguration) throws {
        devices = []
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let txt = devices.map { device in
            let note = device.note ?? ""
            return "\(device.name)\t\(device.ipAddress)\t\(note)"
        }.joined(separator: "\n")
        
        let data = Data(txt.utf8)
        return .init(regularFileWithContents: data)
    }
}