
import Foundation

struct Device: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var ipAddress: String
    var note: String
    var isReachable: Bool = false
}

class PingManager: ObservableObject {
    static let shared = PingManager()

    @Published var devices: [Device] = [] {
        didSet {
            saveDevices()
        }
    }

    private let fileURL: URL = {
        let documents = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = documents.appendingPathComponent("MultiPing")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("devices.json")
    }()

    private init() {
        loadDevices()
        pingAll(completion: nil)
    }

    func loadDevices() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        devices = (try? JSONDecoder().decode([Device].self, from: data)) ?? []
    }

    func pingDeviceImmediately(_ device: Device) {
        DispatchQueue.global(qos: .background).async {
            var updated = device
            updated.isReachable = self.ping(ip: device.ipAddress)
            DispatchQueue.main.async {
                if let index = self.devices.firstIndex(where: { $0.id == updated.id }) {
                    self.devices[index] = updated
                }
            }
        }
    }
    func saveDevices() {
        try? JSONEncoder().encode(devices).write(to: fileURL)
    }

    func pingAll(completion: (([Device]) -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            var updatedDevices: [Device] = []
            for var device in self.devices {
                let reachable = self.ping(ip: device.ipAddress)
                device.isReachable = reachable
                updatedDevices.append(device)
            }
            DispatchQueue.main.async {
                self.devices = updatedDevices
                completion?(updatedDevices)
            }
        }
    }

    private func ping(ip: String) -> Bool {
        let possiblePaths = ["/sbin/ping", "/usr/bin/ping"]
        guard let pingPath = possiblePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            print("Ping binary not found on this system.")
            return false
        }

        let task = Process()
        task.launchPath = pingPath
        task.arguments = ["-c", "1", ip]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print("Ping output for \(ip):\n\(output)")
            }

            print("Ping exit status for \(ip): \(task.terminationStatus)")
            return task.terminationStatus == 0
        } catch {
            print("Failed to ping \(ip): \(error)")
            return false
        }
    }
}
