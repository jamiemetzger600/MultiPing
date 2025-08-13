import SwiftUI
import Foundation
import UniformTypeIdentifiers
import Combine

// MARK: - Main View (Restored + Interval TextField)
struct DeviceListView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @StateObject var pingManager = PingManager.shared
    @State private var newDevice = Device(name: "", ipAddress: "", note: "") // Keep for potential future inline add
    @State private var selectedDeviceIDs = Set<UUID>()
    @State private var showingFileImporter = false
    @State private var importError: String?
    @State private var showingErrorAlert = false
    @State private var deviceToEdit: Device? = nil
    @State private var isExporting: Bool = false // For CSV
    @State private var documentToExport: DeviceListDocument?
    @State private var isExportingTxt: Bool = false // For TXT
    @State private var showingAddDeviceSheet = false
    @Environment(\.dismiss) var dismiss // For potential sheet dismissal
    @State private var showingAlert = false // Keep for import/export status
    @State private var alertMessage = "" // Keep for import/export status

    // --- State for Interval TextField ---
    @State private var currentInterval: Double = 5.0 // Default, will be updated
    @State private var intervalString: String = "5" // For the text field binding
    // --- End Interval State ---
    
    // Computed property to bind to the mode selector
    private var selectedMode: Binding<String> {
        Binding(
            get: { self.appDelegate.currentMode },
            set: { newMode in 
                print("DeviceListView: Mode picker changed to \(newMode). Requesting switch.")
                self.appDelegate.switchMode(to: newMode)
            }
        )
    }
    
    var selectedIndices: [Int] {
        selectedDeviceIDs.compactMap { id in
            pingManager.devices.firstIndex(where: { $0.id == id })
        }.sorted()
    }
     var canMoveSelectionUp: Bool {
         !selectedIndices.isEmpty && selectedIndices.first != 0
     }
     var canMoveSelectionDown: Bool {
         !selectedIndices.isEmpty && selectedIndices.last != pingManager.devices.count - 1
     }

    var body: some View {
        DeviceListMainContent(
            pingIntervalControl: AnyView(pingIntervalControl),
            deviceListHeader: AnyView(deviceListHeader),
            deviceList: AnyView(deviceListContent),
            listManagementButtons: AnyView(listManagementButtons),
            bottomControls: AnyView(bottomControls)
        )
        .frame(minWidth: 400)
        .sheet(item: $deviceToEdit) { device in
            DeviceEditView(device: device) { editedDevice in
                pingManager.updateDevice(device: editedDevice)
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.plainText, .commaSeparatedText, .rtf],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .background {
            Color.clear
                .alert("Error", isPresented: $showingErrorAlert, presenting: importError) { _ in
                    Button("OK", role: .cancel) {}
                } message: { error in
                    Text(error)
                }
                .fileExporter(
                    isPresented: $isExporting,
                    document: documentToExport,
                    contentType: UTType.commaSeparatedText,
                    defaultFilename: "MultiPing_Devices.csv"
                ) { result in
                    handleExportResult(result, type: "CSV")
                }
                .fileExporter(
                    isPresented: $isExportingTxt,
                    document: documentToExport,
                    contentType: UTType.plainText,
                    defaultFilename: "MultiPing_Devices.txt"
                ) { result in
                    handleExportResult(result, type: "TXT")
                }
        }
        .onAppear {
            // Load interval and set string for TextField
            currentInterval = Double(pingManager.pingInterval)
            intervalString = String(pingManager.pingInterval)
            print("DeviceListView appeared. Initial ping interval loaded: \(currentInterval)s")
        }
    }
    
    // Main content container to simplify the body
    private struct DeviceListMainContent: View {
        let pingIntervalControl: AnyView
        let deviceListHeader: AnyView
        let deviceList: AnyView
        let listManagementButtons: AnyView
        let bottomControls: AnyView
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                pingIntervalControl
                    .padding([.horizontal, .top])
                
                Divider()
                
                deviceListHeader
                    .padding(.horizontal)
                    .padding(.bottom, 5)
                
                deviceList
                
                listManagementButtons
                    .padding(.horizontal)
                
                Divider()
                
                bottomControls
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
    }
    
    // Extracted subviews
    private var deviceListHeader: AnyView {
        AnyView(
            HStack {
                Text("Devices").font(.title2)
                Spacer()
                Button("Edit") {
                    if selectedDeviceIDs.count == 1, 
                       let selectedID = selectedDeviceIDs.first,
                       let device = pingManager.devices.first(where: { $0.id == selectedID }) {
                        deviceToEdit = device
                    }
                }
                .disabled(selectedDeviceIDs.count != 1)
            }
        )
    }
    
    private var deviceListContent: AnyView {
        AnyView(
            List(selection: $selectedDeviceIDs) {
                ForEach(pingManager.devices) { device in
                    DeviceRowView(device: device)
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("Edit") {
                                deviceToEdit = device
                            }
                            Button("Delete") {
                                if let index = pingManager.devices.firstIndex(where: { $0.id == device.id }) {
                                    pingManager.devices.remove(at: index)
                                }
                            }
                        }
                }
                .onMove(perform: moveDevices)
            }
            .listStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDeleteCommand(perform: deleteSelected)
        )
    }
    
    private var listManagementButtons: AnyView {
        AnyView(
            ListManagementButtonsView(
                selectedIDs: selectedDeviceIDs,
                canMoveUp: canMoveSelectionUp,
                canMoveDown: canMoveSelectionDown,
                deleteAction: deleteSelected,
                moveUpAction: moveSelectedUp,
                moveDownAction: moveSelectedDown
            )
        )
    }
    
    private var bottomControls: AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                AddDeviceView(newDevice: $newDevice, addAction: addDevice)
                    .padding(.bottom, 5)
                
                Divider()
                
                ImportExportView(
                    pingManager: pingManager,
                    showingFileImporter: $showingFileImporter,
                    isExportingCSV: $isExporting,
                    isExportingTXT: $isExportingTxt,
                    prepareExportDocument: {
                        guard !pingManager.devices.isEmpty else { return }
                        documentToExport = DeviceListDocument(devices: pingManager.devices)
                    }
                )
                
                Divider()
                
                modeSelector
            }
        )
    }

    // MARK: - Subviews (Restored Structure + Interval)

    private var pingIntervalControl: some View {
        HStack {
            Text("Ping Interval:")
            TextField("Secs", text: $intervalString)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 60) // Widen to accommodate decimals
                .multilineTextAlignment(.trailing)
                .onSubmit { // Validate on submit (Enter key)
                    validateAndUpdateInterval()
                }
            Text("s")
            Spacer() // Pushes control to leading edge
        }
    }

    private var modeSelector: some View {
        HStack {
            Text("Display Mode:")
            Picker("Mode", selection: selectedMode) { // Added label for clarity
                Text("Menu Bar").tag("menuBar")
                Text("Floating Window").tag("floatingWindow")
            }
            .pickerStyle(.segmented)
            .labelsHidden() // Hide the picker's own label
            Spacer() // Pushes control to leading edge
        }
    }

    // MARK: - Helper Functions (Restored + Interval Validation)

    // Keep handleImportResult, handleExportResult
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                print("DeviceListView: Importing from URL: \(url.path)")
                importDevicesFromFile(url: url)
            } else {
                print("DeviceListView: Import succeeded but no URL was returned.")
                importError = "Import failed: No file selected."
                showingErrorAlert = true
            }
        case .failure(let error):
            print("DeviceListView: Import failed: \(error.localizedDescription)")
            importError = error.localizedDescription
            showingErrorAlert = true
        }
    }

    private func handleExportResult(_ result: Result<URL, Error>, type: String) {
        switch result {
        case .success(let url):
            print("DeviceListView: Successfully exported \(type) devices to \(url.path)")
        case .failure(let error):
            print("DeviceListView: Failed to export \(type) devices: \(error.localizedDescription)")
            importError = "Failed to export \(type): \(error.localizedDescription)"
            showingErrorAlert = true
        }
        documentToExport = nil
    }

    // Keep list management functions: deleteSelected, moveSelectedUp, moveSelectedDown
    private func deleteSelected() {
        let sortedIndices = selectedIndices.sorted(by: >) // Ensure correct deletion order
        let nextSelectionCandidateIndex = sortedIndices.last.map { $0 + 1 } // Try selecting below deleted range

        // Convert UUIDs to indices carefully before deleting
        let indicesToDelete = selectedDeviceIDs.compactMap { id in
            pingManager.devices.firstIndex(where: { $0.id == id })
        }.sorted(by: >) // Sort indices descending for safe removal

        for index in indicesToDelete {
            pingManager.devices.remove(at: index)
        }

        // Smart selection after delete
        if let candidateIndex = nextSelectionCandidateIndex, candidateIndex < pingManager.devices.count {
            // Select item after the deleted block if possible
             selectedDeviceIDs = [pingManager.devices[candidateIndex].id]
        } else if let lastRemainingIndex = pingManager.devices.indices.last {
            // Otherwise select the last item if list not empty
             selectedDeviceIDs = [pingManager.devices[lastRemainingIndex].id]
        } else {
            // List is empty
             selectedDeviceIDs.removeAll()
        }
    }

    // Add moveDevices needed for .onMove
     private func moveDevices(from source: IndexSet, to destination: Int) {
         pingManager.devices.move(fromOffsets: source, toOffset: destination)
         // Optionally update selection if needed, but usually fine
     }


    private func moveSelectedUp() {
        guard !selectedIndices.isEmpty, let firstIndex = selectedIndices.first, firstIndex > 0 else { return }
        let indices = selectedIndices // Already sorted ascending
        var newSelectionIDs = Set<UUID>()
        // Move block from bottom up
        for index in indices {
            pingManager.devices.swapAt(index, index - 1)
            newSelectionIDs.insert(pingManager.devices[index - 1].id)
        }
         selectedDeviceIDs = newSelectionIDs
    }

    private func moveSelectedDown() {
        guard !selectedIndices.isEmpty, selectedIndices.last! < pingManager.devices.count - 1 else { return }
        let indices = selectedIndices.reversed() // Iterate downwards
        var newSelectionIDs = Set<UUID>()
         // Move block from top down
        for index in indices {
            pingManager.devices.swapAt(index, index + 1)
             newSelectionIDs.insert(pingManager.devices[index + 1].id)
        }
         selectedDeviceIDs = newSelectionIDs
    }

    // Keep import function using FileImporter class
    private func importDevicesFromFile(url: URL) {
        FileImporter.shared.importDevicesFromFile(url) { newDevices in
            if !newDevices.isEmpty {
                // Append and trigger ping
                self.pingManager.devices.append(contentsOf: newDevices)
                self.pingManager.pingAll() // Or maybe ping only new ones? pingAll is safer.
                self.alertMessage = "Successfully imported \(newDevices.count) device(s)."
                self.showingAlert = true
            } else {
                // Show error if no valid devices found
                 self.importError = "No valid devices found in the imported file or file was empty."
                 self.showingErrorAlert = true
            }
        }
    }

    // Ensure addDevice uses the @State variable
    private func addDevice() {
        guard !newDevice.name.isEmpty, !newDevice.ipAddress.isEmpty else { return }
        
        // The add button already calls validateAndAdd which has validation,
        // so this is now just a simple call to the PingManager
        if pingManager.addDevice(newDevice) {
            // Clear the input fields only if device was successfully added
            newDevice = Device(name: "", ipAddress: "", note: "")
        }
    }

    // Add back the function for adding multiple devices from sheet input
    private func addSingleOrMultipleDevices(inputString: String) {
        let lines = inputString.split(whereSeparator: \.isNewline)
        var addedCount = 0
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            guard !trimmedLine.isEmpty else { continue }

            var newDev: Device?
            if trimmedLine.contains(",") {
                let parts = trimmedLine.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty {
                    // Attempt to create device from Name,IP format
                    newDev = Device(name: String(parts[0]), ipAddress: String(parts[1]))
                } else {
                    print("Skipping invalid CSV format line: \(trimmedLine)")
                }
            } else {
                // Assume it's just an IP or hostname (use it as both name and IP)
                newDev = Device(name: trimmedLine, ipAddress: trimmedLine)
            }

            // Add the device if successfully created
            if let deviceToAdd = newDev {
                // Use PingManager's addDevice, which handles duplicates and returns Bool
                if pingManager.addDevice(deviceToAdd) {
                    addedCount += 1
                }
            }
        }
        // Optional: Provide feedback after attempting to add all devices
        if addedCount > 0 {
            print("Added \(addedCount) new devices.")
            // Optionally trigger a pingAll or rely on individual pings from addDevice
            // pingManager.pingAll()
        } else {
             print("No new devices were added from the provided text.")
             // Optionally show an alert to the user
             // self.importError = "No new devices were added from the input."
             // self.showingErrorAlert = true
        }
    }

    // --- Interval Validation Function ---
    private func validateAndUpdateInterval() {
        if let newIntervalValue = Double(intervalString), newIntervalValue > 0 && newIntervalValue <= 60 {
            // Round to 2 decimal places for display
            let roundedValue = (newIntervalValue * 100).rounded() / 100
            print("DeviceListView: Interval TextField submitted: \(roundedValue)s. Updating PingManager.")
            currentInterval = roundedValue
            pingManager.updatePingInterval(roundedValue)
            
            // Format with up to 2 decimal places, but no trailing zeros
            if roundedValue == roundedValue.rounded() {
                // It's a whole number, display as integer
                intervalString = String(Int(roundedValue))
            } else {
                // It has decimal places, format with at most 2 digits
                intervalString = String(format: "%.2f", roundedValue).replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
            }
        } else {
            print("DeviceListView: Invalid interval input '\(intervalString)'. Reverting to default (5s).")
            
            // Reset to default 5 seconds
            currentInterval = 5.0
            pingManager.updatePingInterval(5.0)
            intervalString = "5"
        }
        
        // Ensure the ping timer is running with the updated interval
        print("DeviceListView: Ensuring ping timer is running with interval: \(self.pingManager.pingInterval)s")
        self.pingManager.startPingTimer()
    }
} // End DeviceListView

// MARK: - Row View (Ensure this matches the expected structure)
struct DeviceRowView: View {
    let device: Device

    var body: some View {
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
    }
}

// MARK: - Subviews for DeviceListView (Ensure these match the expected structure)

// Removed inline AddDeviceView struct definition from here

struct ImportExportView: View {
    @ObservedObject var pingManager: PingManager
    @Binding var showingFileImporter: Bool
    @Binding var isExportingCSV: Bool
    @Binding var isExportingTXT: Bool
    let prepareExportDocument: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Import/Export").font(.headline)
            HStack {
                Button {
                    showingFileImporter = true
                } label: {
                    Text("Import Devices")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Button {
                    print("ImportExportView: Export CSV clicked.")
                    prepareExportDocument()
                    isExportingCSV = true
                } label: {
                     Text("Export (CSV)")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .disabled(pingManager.devices.isEmpty)

                Button {
                    print("ImportExportView: Export TXT clicked.")
                    prepareExportDocument()
                    isExportingTXT = true
                } label: {
                     Text("Export (TXT)")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .disabled(pingManager.devices.isEmpty)
            }
        }
    }
}

struct ListManagementButtonsView: View {
    let selectedIDs: Set<UUID>
    let canMoveUp: Bool
    let canMoveDown: Bool
    let deleteAction: () -> Void
    let moveUpAction: () -> Void
    let moveDownAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: deleteAction) {
                Text("Delete")
                    .frame(maxWidth: .infinity)
            }
            .disabled(selectedIDs.isEmpty)

            Button(action: moveUpAction) {
                Text("↑")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!canMoveUp)

            Button(action: moveDownAction) {
                Text("↓")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!canMoveDown)
        }
    }
}

// MARK: - Status View (Keep or remove if unused)
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

// MARK: - AddDeviceInputView (for sheet)
struct AddDeviceInputView: View {
    @State private var inputString: String = ""
    @Environment(\.dismiss) var dismiss
    var onAdd: (String) -> Void // Closure to pass the input back

    var body: some View {
        VStack {
            Text("Add Device(s)")
                .font(.headline)
                .padding(.bottom)

            Text("Enter IP address, hostname, or Name,IP per line.")
                .font(.subheadline)
                .foregroundColor(.gray)

            TextEditor(text: $inputString)
                .frame(height: 150) // Adjust height as needed
                .border(Color.gray.opacity(0.5))
                .padding(.bottom)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Button("Add") {
                    if !inputString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onAdd(inputString) // Call the closure
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 300)
    }
}

struct AddDeviceView: View {
    @Binding var newDevice: Device
    let addAction: () -> Void
    @ObservedObject private var pingManager = PingManager.shared
    @State private var showingDuplicateAlert = false
    @State private var showingInvalidIPAlert = false
    @Environment(\.openWindow) private var openWindow
    
    // Check for duplicate
    private func isDuplicate(_ ip: String) -> Bool {
        return pingManager.devices.contains { $0.ipAddress == ip }
    }
    
    // Function to handle adding with validation
    private func validateAndAdd() {
        print("AddDeviceView: Validating IP: \(newDevice.ipAddress)")
        
        // Check if IP is valid first using the shared validation
        if !pingManager.isValidIPAddress(newDevice.ipAddress) {
            print("AddDeviceView: Invalid IP detected: \(newDevice.ipAddress)")
            showingInvalidIPAlert = true
            return
        }
        
        // Check for duplicates
        if isDuplicate(newDevice.ipAddress) {
            print("AddDeviceView: Duplicate IP detected: \(newDevice.ipAddress)")
            showingDuplicateAlert = true
            return
        }
        
        print("AddDeviceView: Validation passed for IP: \(newDevice.ipAddress)")
        // If we get here, validation passed
        addAction()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) { // Reduced spacing slightly if needed
            Text("Add Device").font(.headline)
            TextField("Name", text: $newDevice.name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            TextField("IP Address", text: $newDevice.ipAddress)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            // Add the missing Note TextField
            TextField("Note (Optional)", text: Binding(
                get: { newDevice.note ?? "" },
                set: { newDevice.note = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(RoundedBorderTextFieldStyle())

            VStack(spacing: 5) {
                Button(action: validateAndAdd) {
                    Text("Add")
                        // Ensure button spans width and is styled
                        .frame(maxWidth: .infinity)
                }
                // Disable button if name or IP is empty
                .disabled(newDevice.name.isEmpty || newDevice.ipAddress.isEmpty)
                
                // Add Find Devices button
                Button(action: {
                    openWindow(id: "findDevices")
                }) {
                    Text("Find Devices")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .alert("Duplicate IP Address", isPresented: $showingDuplicateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A device with IP address '\(newDevice.ipAddress)' already exists.")
        }
        .alert("Invalid IP Address", isPresented: $showingInvalidIPAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The IP address '\(newDevice.ipAddress)' appears to be invalid. Please enter a valid IPv4 address or hostname.")
        }
    }
}
