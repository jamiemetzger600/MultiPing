import SwiftUI
import Foundation

// Remove the extension since we already have shared in the class
struct DeviceListView: View {
    // EnvironmentObject for AppDelegate access
    @EnvironmentObject var appDelegate: AppDelegate
    
    // Local ObservedObject for PingManager (could also be passed via environment if preferred)
    @ObservedObject var pingManager = PingManager.shared
    
    // UI State
    @State private var newDevice = Device(name: "", ipAddress: "", note: "")
    @State private var selectedDeviceIDs = Set<UUID>()
    @State private var showingFileImporter = false
    @State private var importError: String?
    @State private var showingErrorAlert = false
    
    // Computed property to access the current mode from AppDelegate
    private var currentMode: Binding<String> {
        Binding(
            get: { appDelegate.currentMode },
            set: { newMode in
                // Trigger the mode switch in AppDelegate
                appDelegate.switchMode(to: newMode)
            }
        )
    }

    // No longer needed controllers here, handled by AppDelegate
    // private let floatingController = FloatingWindowController.shared
    // private let mainWindowManager = MainWindowManager.shared

    // Access appDelegate via EnvironmentObject
    // private var appDelegate: AppDelegate? { ... }

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

            // Mode selector - Binds to the computed property
            VStack(alignment: .leading, spacing: 8) {
                Text("Display Mode").font(.headline)
                Picker("Interface", selection: currentMode) { // Use the binding here
                    Text("Menu Bar").tag("menuBar")
                    Text("Float").tag("floatingWindow")
                    // Text("CLI").tag("cli") // Temporarily hide CLI option
                }
                .pickerStyle(SegmentedPickerStyle())
                // No .onChange needed here, the binding handles the update
            }
        }
        .padding(5)
        .frame(idealWidth: 260)
        .frame(minWidth: 240, maxWidth: 320)
        .onAppear {
            // Remove mode setting logic from here
            // AppDelegate handles initial setup
            pingManager.pingAll() // Still start pings
            print("DeviceListView appeared. Current mode from delegate: \(appDelegate.currentMode)")
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
        FileImporter.shared.importDevicesFromFile(url) { newDevices in
            if !newDevices.isEmpty {
                self.pingManager.devices.append(contentsOf: newDevices)
                // Ping all newly added devices
                self.pingManager.pingAll()
            }
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
