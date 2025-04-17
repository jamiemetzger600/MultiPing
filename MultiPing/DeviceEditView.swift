import SwiftUI

struct DeviceEditView: View {
    // Use @State for local editing copy
    @State private var editableDevice: Device
    // Closure to call when saving
    var onSave: (Device) -> Void
    // Environment variable to dismiss the sheet
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var pingManager = PingManager.shared
    @State private var showingDuplicateAlert = false
    @State private var showingInvalidIPAlert = false
    
    // The original device's IP for comparison
    private let originalIP: String

    // Initializer to receive the device to edit
    init(device: Device, onSave: @escaping (Device) -> Void) {
        // Initialize the local @State copy with the passed device
        _editableDevice = State(initialValue: device)
        self.onSave = onSave
        self.originalIP = device.ipAddress
        print("DeviceEditView initialized for device: \(device.name)")
    }
    
    // Check for duplicate (excluding current device)
    private func isDuplicate(_ ip: String) -> Bool {
        // If the IP hasn't changed, it's not a duplicate
        if ip == originalIP {
            return false
        }
        
        // Otherwise check if any other device has this IP
        return pingManager.devices.contains { $0.ipAddress == ip && $0.id != editableDevice.id }
    }
    
    // Function to handle saving with validation
    private func validateAndSave() {
        // Check if IP is valid using shared validation
        if !pingManager.isValidIPAddress(editableDevice.ipAddress) {
            showingInvalidIPAlert = true
            return
        }
        
        // Check for duplicates
        if isDuplicate(editableDevice.ipAddress) {
            showingDuplicateAlert = true
            return
        }
        
        // If validation passes, save the device
        onSave(editableDevice)
        dismiss()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Edit Device")
                .font(.title2)

            TextField("Name", text: $editableDevice.name)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("IP Address", text: $editableDevice.ipAddress)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("Note (Optional)", text: Binding(
                get: { editableDevice.note ?? "" },
                set: { editableDevice.note = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(RoundedBorderTextFieldStyle())

            Spacer() // Pushes buttons to the bottom

            HStack {
                Button("Cancel") {
                    print("DeviceEditView: Cancel button clicked.")
                    dismiss() // Dismiss the sheet
                }
                .keyboardShortcut(.cancelAction) // Allow Esc key

                Spacer()

                Button("Save") {
                    print("DeviceEditView: Save button clicked for device ID: \(editableDevice.id)")
                    validateAndSave() // Use validation before saving
                }
                .buttonStyle(.borderedProminent)
                .disabled(editableDevice.name.isEmpty || editableDevice.ipAddress.isEmpty) // Basic validation
                .keyboardShortcut(.defaultAction) // Allow Enter key
            }
        }
        .padding()
        .frame(minWidth: 300, idealWidth: 350, minHeight: 250) // Give it some size
        .alert("Duplicate IP Address", isPresented: $showingDuplicateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Another device with IP address '\(editableDevice.ipAddress)' already exists.")
        }
        .alert("Invalid IP Address", isPresented: $showingInvalidIPAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The IP address '\(editableDevice.ipAddress)' appears to be invalid. Please enter a valid IPv4 address or hostname.")
        }
        .onAppear {
             print("DeviceEditView appeared.")
        }
    }
}

// Preview Provider (Optional, but helpful)
struct DeviceEditView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample device for preview
        let sampleDevice = Device(name: "Sample Router", ipAddress: "192.168.1.1", note: "Main network router")
        // Provide a dummy onSave closure for preview
        DeviceEditView(device: sampleDevice, onSave: { editedDevice in
            print("Preview Save: \(editedDevice)")
        })
    }
} 