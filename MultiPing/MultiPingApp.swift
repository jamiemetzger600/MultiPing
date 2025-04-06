// MultiPingApp.swift
// Menu bar now adjusts width to fit capsule buttons for each device name

import SwiftUI
import AppKit
import Combine

@main
struct MultiPingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Devices", id: "devices") {
            DeviceListView()
                .frame(width: 300, height: 500)
        }
        // Removed fixed default size to allow dynamic sizing based on content
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var pingManager = PingManager.shared
    var cancellable: AnyCancellable?
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupCustomMenuBarView()
        updateMenu()
        // openFloatingWindow()

        cancellable = pingManager.$devices
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.setupCustomMenuBarView()
                self?.updateMenu()
            }

        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [self] _ in
            self.pingManager.pingAll { updated in
                self.setupCustomMenuBarView()
                if updated.contains(where: { !$0.isReachable }) {
                    NSApp.requestUserAttention(.criticalRequest)
                }
            }
        }
    }

    @objc func openSettings() {
        if let url = URL(string: "multiping://devices") {
            NSWorkspace.shared.open(url)
        }
    }

    func openFloatingWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 100, y: 100, width: 200, height: 500),
            styleMask: [.titled, .closable, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.title = "Status Panel"
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: DeviceListView())
        panel.makeKeyAndOrderFront(nil)
    }

    @objc func showFloating() {
        openFloatingWindow()
    }

    func setupCustomMenuBarView() {
        let capsuleRow = HStack(spacing: 6) {
            ForEach(pingManager.devices) { device in
                Text(device.name)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(device.isReachable ? Color.green : Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .font(.system(size: 10, weight: .medium))
            }
        }
        .padding(.horizontal, 6)

        let hostingView = NSHostingView(rootView: capsuleRow)
        hostingView.layout()
        let size = hostingView.fittingSize

        statusItem.length = size.width + 12
        statusItem.button?.subviews.forEach { $0.removeFromSuperview() }
        statusItem.button?.addSubview(hostingView)

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.centerYAnchor.constraint(equalTo: statusItem.button!.centerYAnchor),
            hostingView.centerXAnchor.constraint(equalTo: statusItem.button!.centerXAnchor)
        ])
    }

    func updateMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Edit Devices", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())

        let capsuleRowView = NSHostingView(rootView:
            HStack(spacing: 8) {
                ForEach(pingManager.devices) { device in
                    Text(device.name)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(device.isReachable ? Color.green : Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        )

        let customItem = NSMenuItem()
        customItem.view = capsuleRowView
        menu.addItem(customItem)

        statusItem.menu = menu
    }
}
