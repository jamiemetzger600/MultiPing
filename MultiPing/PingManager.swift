import Foundation


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
            let dispatchGroup = DispatchGroup()
            var updatedDevices = self.devices
            
            // Create a concurrent queue for parallel execution
            let queue = DispatchQueue(label: "com.multiping.pingqueue", attributes: .concurrent)
            
            // Start all pings in parallel
            for index in updatedDevices.indices {
                dispatchGroup.enter()
                queue.async {
                    let reachable = self.ping(ip: updatedDevices[index].ipAddress)
                    DispatchQueue.main.async {
                        updatedDevices[index].isReachable = reachable
                        dispatchGroup.leave()
                    }
                }
            }
            
            // Wait for all pings to complete
            dispatchGroup.wait()
            
            // Update the devices array on the main thread
            DispatchQueue.main.async {
                // Only update if there are actual changes
                let hasChanges = zip(self.devices, updatedDevices).contains { $0.isReachable != $1.isReachable }
                if hasChanges {
                    self.devices = updatedDevices
                }
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
        task.arguments = ["-c", "1", "-W", "1", ip]  // Added -W 1 to limit wait time to 1 second

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            print("Failed to ping \(ip): \(error)")
            return false
        }
    }
}
