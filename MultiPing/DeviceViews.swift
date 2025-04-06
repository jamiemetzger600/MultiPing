import SwiftUI
import Foundation

struct DeviceListView: View {
    @ObservedObject var pingManager = PingManager.shared
    @State private var newDevice = Device(name: "", ipAddress: "", note: "")
    @State private var selectedDeviceID: UUID?

    var selectedIndex: Int? {
        pingManager.devices.firstIndex(where: { $0.id == selectedDeviceID })
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Devices").font(.title2).padding(.bottom, 5)

            List {
                ForEach(pingManager.devices) { device in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(device.name).font(.headline)
                            Text(device.ipAddress).font(.subheadline)
                            Text(device.note).font(.caption)
                        }
                        Spacer()
                        Circle()
                            .fill(device.isReachable ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDeviceID = device.id
                    }
                    .background(selectedDeviceID == device.id ? Color.gray.opacity(0.2) : Color.clear)
                }
            }

            HStack {
                Button("Delete Selected", action: deleteSelected)
                    .fixedSize()
                Button("Move Up", action: moveSelectedUp)
                    .fixedSize()
                Button("Move Down", action: moveSelectedDown)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 5)

            Divider()

            Text("Add Device").font(.headline)
            TextField("Name", text: $newDevice.name)
            TextField("IP Address", text: $newDevice.ipAddress)
            TextField("Note", text: $newDevice.note)
            Button(action: {
                guard !newDevice.name.isEmpty, !newDevice.ipAddress.isEmpty else { return }
                pingManager.devices.append(newDevice)
                pingManager.pingDeviceImmediately(newDevice)
                newDevice = Device(name: "", ipAddress: "", note: "")
            }) {
                Text("Add")
            }
            .padding(.top, 4)
        }
        .padding(5)
        .frame(minWidth: 0, idealWidth: nil, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
    }

    func deleteSelected() {
        if let index = selectedIndex {
            pingManager.devices.remove(at: index)
            selectedDeviceID = nil
        }
    }

    func moveSelectedUp() {
        if let index = selectedIndex, index > 0 {
            pingManager.devices.swapAt(index, index - 1)
        }
    }

    func moveSelectedDown() {
        if let index = selectedIndex, index < pingManager.devices.count - 1 {
            pingManager.devices.swapAt(index, index + 1)
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
