import SwiftUI
import Foundation

// Make FloatingWindowController a shared instance
extension FloatingWindowController {
    static let shared = FloatingWindowController()
}

struct DeviceListView: View {
    @ObservedObject var pingManager = PingManager.shared
    @State private var newDevice = Device(name: "", ipAddress: "", note: "")
    @State private var selectedDeviceIDs = Set<UUID>()
    @State private var showingFileImporter = false
    @State private var importError: String?
    @State private var showingErrorAlert = false
    @State private var selectedMode = "menuBar"  // Default to menuBar
    
    // Use the shared instance
    private let floatingController = FloatingWindowController.shared

    var selectedIndices: [Int] {
        selectedDeviceIDs.compactMap { id in
            pingManager.devices.firstIndex(where: { $0.id == id })
        }.sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Devices")
                .font(.title2)
                .padding(.bottom, 5)

            List(selection: $selectedDeviceIDs) {
                ForEach(pingManager.devices) { device in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(device.name).font(.headline)
                            Text(device.ipAddress).font(.subheadline)
                            if let note = device.note, !note.isEmpty {
                                Text(note).font(.caption)
                            }
                        }
                        Spacer()
                        Circle()
                            .fill(device.isReachable ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                    }
                    .contentShape(Rectangle())
                }
            }
            .frame(maxHeight: .infinity)
            .onDeleteCommand(perform: deleteSelected)

            // Device management buttons in a more compact layout
            HStack(spacing: 4) {
                Button(action: deleteSelected) {
                    Text("Delete")
                        .frame(maxWidth: .infinity)
                }
                .disabled(selectedDeviceIDs.isEmpty)
                
                Button(action: moveSelectedUp) {
                    Text("↑")
                        .frame(maxWidth: .infinity)
                }
                .disabled(selectedIndices.isEmpty || selectedIndices.first == 0)
                
                Button(action: moveSelectedDown) {
                    Text("↓")
                        .frame(maxWidth: .infinity)
                }
                .disabled(selectedIndices.isEmpty || selectedIndices.last == pingManager.devices.count - 1)
            }
            .padding(.vertical, 5)

            Divider()

            // Add device section
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Device").font(.headline)
                TextField("Name", text: $newDevice.name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("IP Address", text: $newDevice.ipAddress)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Note (Optional)", text: Binding(
                    get: { newDevice.note ?? "" },
                    set: { newDevice.note = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: addDevice) {
                    Text("Add")
                        .frame(maxWidth: .infinity)
                }
                .disabled(newDevice.name.isEmpty || newDevice.ipAddress.isEmpty)
                .buttonStyle(.borderedProminent)
            }

            Divider()
                .padding(.vertical, 8)

            // Add import/export section above the mode selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Import/Export").font(.headline)
                HStack {
                    Button("Import Devices") {
                        showingFileImporter = true
                    }
                    .fileImporter(
                        isPresented: $showingFileImporter,
                        allowedContentTypes: [.commaSeparatedText, .text, .rtf],
                        allowsMultipleSelection: false
                    ) { result in
                        switch result {
                        case .success(let files):
                            if let file = files.first {
                                importDevicesFromFile(url: file)
                            }
                        case .failure(let error):
                            importError = error.localizedDescription
                            showingErrorAlert = true
                        }
                    }
                }
            }
            .padding(.vertical, 5)
            Divider()

            // Mode selector at the bottom
            VStack(alignment: .leading, spacing: 8) {
                Text("Display Mode").font(.headline)
                Picker("Interface", selection: $selectedMode) {
                    Text("Menu Bar").tag("menuBar")
                    Text("Float").tag("floatingWindow")
                    Text("CLI").tag("cli")
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedMode) { newMode in
                    print("Mode changed to: \(newMode)")
                    UserDefaults.standard.set(newMode, forKey: "preferredInterface")
                    
                    switch newMode {
                    case "menuBar":
                        // Hide floating window
                        floatingController.hide()
                        // Show menu bar and keep main window visible
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.showMenuBar()
                        }
                    case "floatingWindow":
                        // Hide menu bar and main window first
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.hideMenuBar()
                            appDelegate.hideMainWindow()
                        }
                        // Then show floating window
                        DispatchQueue.main.async {
                            floatingController.show()
                        }
                    case "cli":
                        // Hide everything except CLI
                        floatingController.hide()
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.hideMenuBar()
                            appDelegate.hideMainWindow()
                        }
                        CLIRunner.shared.start()
                    default:
                        break
                    }
                }
            }
        }
        .padding(5)
        .frame(idealWidth: 260)
        .frame(minWidth: 240, maxWidth: 320)
        .onAppear {
            // On first launch, ensure menu bar is visible but don't change window visibility
            selectedMode = "menuBar"  // Ensure default selection is Menu Bar
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.showMenuBar()
            }
            // Start pinging devices immediately
            pingManager.pingAll()
        }
        .alert("Import Error", isPresented: $showingErrorAlert, presenting: importError) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error)
        }
    }

    private func addDevice() {
        guard !newDevice.name.isEmpty, !newDevice.ipAddress.isEmpty else { return }
        pingManager.devices.append(newDevice)
        pingManager.pingDeviceImmediately(newDevice)
        newDevice = Device(name: "", ipAddress: "", note: "")
    }

    private func deleteSelected() {
        // Sort indices in descending order to avoid index shifting issues
        let sortedIndices = selectedIndices.sorted(by: >)
        
        // Store the index after the last selected item for re-selection
        let nextIndex = sortedIndices.last.map { $0 + 1 }
        
        // Remove selected devices
        for index in sortedIndices {
            pingManager.devices.remove(at: index)
        }
        
        // Select the next item if available
        if let nextIndex = nextIndex, nextIndex < pingManager.devices.count {
            selectedDeviceIDs = [pingManager.devices[nextIndex].id]
        } else if let lastIndex = pingManager.devices.indices.last {
            // If we deleted the last item(s), select the new last item
            selectedDeviceIDs = [pingManager.devices[lastIndex].id]
        } else {
            // If no items left, clear selection
            selectedDeviceIDs.removeAll()
        }
    }

    private func moveSelectedUp() {
        guard !selectedIndices.isEmpty, selectedIndices.first! > 0 else { return }
        let indices = selectedIndices
        for index in indices {
            pingManager.devices.swapAt(index, index - 1)
        }
        // Update selection to maintain the same items selected
        selectedDeviceIDs = Set(indices.map { pingManager.devices[$0 - 1].id })
    }

    private func moveSelectedDown() {
        guard !selectedIndices.isEmpty, selectedIndices.last! < pingManager.devices.count - 1 else { return }
        let indices = selectedIndices.reversed()
        for index in indices {
            pingManager.devices.swapAt(index, index + 1)
        }
        // Update selection to maintain the same items selected
        selectedDeviceIDs = Set(indices.map { pingManager.devices[$0 + 1].id })
    }

    private func importDevicesFromFile(url: URL) {
        do {
            let content: String
            
            // Handle RTF files differently
            if url.pathExtension.lowercased() == "rtf" {
                guard let rtfData = try? Data(contentsOf: url),
                      let attributedString = try? NSAttributedString(
                        data: rtfData,
                        options: [.documentType: NSAttributedString.DocumentType.rtf],
                        documentAttributes: nil
                      ) else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read RTF file"])
                }
                content = attributedString.string
            } else {
                content = try String(contentsOf: url)
            }
            
            let lines = content.components(separatedBy: .newlines)
            
            for line in lines where !line.isEmpty {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedLine.isEmpty { continue }
                
                if url.pathExtension.lowercased() == "csv" {
                    // Handle CSV format (name,ip,note)
                    let components = trimmedLine.components(separatedBy: ",")
                    if components.count >= 2 {
                        let name = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        let ip = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        let note = components.count > 2 ? components[2].trimmingCharacters(in: .whitespacesAndNewlines) : nil
                        
                        let device = Device(name: name, ipAddress: ip, note: note)
                        pingManager.devices.append(device)
                    }
                } else {
                    // Handle simple text format (assume IP addresses only, use hostname as name)
                    let device = Device(name: trimmedLine, ipAddress: trimmedLine)
                    pingManager.devices.append(device)
                }
            }
            
            // Ping all new devices
            pingManager.pingAll()
            
        } catch {
            importError = "Failed to import devices: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
}

struct DeviceStatusView: View {
    var device: Device

    var body: some View {
        Text(device.name)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(device.isReachable ? Color.green : Color.red)
            .foregroundColor(.white)
            .cornerRadius(12)
    }
}
