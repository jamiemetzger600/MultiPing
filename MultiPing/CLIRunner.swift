//
//  CLIRunner.swift
//  MultiPing
//
//  Created by Jamie Metzger on 4/6/25.
//


import Foundation

class CLIRunner {
    static let shared = CLIRunner()

    private let fileURL: URL = {
        let manager = FileManager.default
        let folder = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return folder.appendingPathComponent("com.yourcompany.MultiPing/devices.json")
    }()

    func start() {
        print("Running Multi-Ping in CLI mode...\n")
        guard let data = try? Data(contentsOf: fileURL),
              let devices = try? JSONDecoder().decode([Device].self, from: data) else {
            print("Failed to load device list.")
            return
        }

        let group = DispatchGroup()

        for device in devices {
            group.enter()
            ping(ip: device.ipAddress) { reachable in
                let status = reachable ? "✅" : "❌"
                print("\(status) \(device.name) (\(device.ipAddress))")
                group.leave()
            }
        }

        group.wait()
        print("\nDone.")
        exit(0)
    }

    private func ping(ip: String, completion: @escaping (Bool) -> Void) {
        let task = Process()
        task.launchPath = "/sbin/ping"
        task.arguments = ["-c", "1", "-W", "1", ip]

        task.terminationHandler = { process in
            completion(process.terminationStatus == 0)
        }

        do {
            try task.run()
        } catch {
            completion(false)
        }
    }
}
