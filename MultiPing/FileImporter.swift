import Foundation
import AppKit
import UniformTypeIdentifiers

class FileImporter {
    static let shared = FileImporter()
    
    func importDevicesFromFile(_ url: URL, completion: @escaping ([Device]) -> Void) {
        do {
            let text: String
            if url.pathExtension.lowercased() == "rtf" {
                // Handle RTF files
                let data = try Data(contentsOf: url)
                guard let attributedString = NSAttributedString(rtf: data, documentAttributes: nil) else {
                    throw NSError(domain: "FileImporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to read RTF file"])
                }
                text = attributedString.string
            } else {
                // Handle plain text files
                text = try String(contentsOf: url, encoding: .utf8)
            }
            
            let lines = text.components(separatedBy: .newlines)
            var devices: [Device] = []
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedLine.isEmpty else { continue }
                
                if trimmedLine.contains(",") {
                    // CSV format: name,ip,note
                    let components = trimmedLine.components(separatedBy: ",")
                    if components.count >= 2 {
                        let name = components[0].trimmingCharacters(in: .whitespaces)
                        let ipAddress = components[1].trimmingCharacters(in: .whitespaces)
                        let note = components.count > 2 ? components[2].trimmingCharacters(in: .whitespaces) : nil
                        devices.append(Device(name: name, ipAddress: ipAddress, note: note))
                    }
                } else {
                    // Simple format: just IP or hostname
                    devices.append(Device(name: trimmedLine, ipAddress: trimmedLine))
                }
            }
            
            completion(devices)
        } catch {
            print("Error importing devices: \(error)")
            completion([])
        }
    }
    
    func showImportDialog(completion: @escaping ([Device]) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.plainText, .rtf, .commaSeparatedText]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.importDevicesFromFile(url, completion: completion)
            } else {
                completion([])
            }
        }
    }
} 