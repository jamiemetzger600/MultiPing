import SwiftUI
import AppKit

struct FloatingDeviceListView: View {
    @ObservedObject var pingManager = PingManager.shared
    @State private var alwaysOnTop = UserDefaults.standard.bool(forKey: "alwaysOnTop")
    weak var windowRef: NSWindow?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            Divider()
            deviceListSection
        }
        .padding()
    }

    private var headerSection: some View {
        HStack {
            Text("Multi-Ping")
                .font(.title3)
                .bold()
            Spacer()
            Button(action: {
                alwaysOnTop.toggle()
                UserDefaults.standard.set(alwaysOnTop, forKey: "alwaysOnTop")
                windowRef?.level = alwaysOnTop ? .floating : .normal
            }) {
                Image(systemName: alwaysOnTop ? "pin.fill" : "pin.slash")
                    .foregroundColor(alwaysOnTop ? .blue : .gray)
                    .help("Toggle Always on Top")
            }
            .buttonStyle(.borderless)
        }
    }

    private var deviceListSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(pingManager.devices) { device in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(device.isReachable ? Color.green : Color.red)
                            .frame(width: 10, height: 10)

                        Text(device.name)
                            .font(.body)
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }
        }
    }
}

struct SimplifiedDeviceView: View {
    @ObservedObject var pingManager = PingManager.shared
    @State private var alwaysOnTop = UserDefaults.standard.bool(forKey: "alwaysOnTop")
    @State private var showNotes = false
    weak var windowRef: NSWindow?
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 4) {
                // Header with controls
                HStack(spacing: 8) {
                    Toggle("Notes", isOn: $showNotes)
                        .toggleStyle(.checkbox)
                        .controlSize(.small)
                    Spacer()
                    Button(action: {
                        alwaysOnTop.toggle()
                        UserDefaults.standard.set(alwaysOnTop, forKey: "alwaysOnTop")
                        windowRef?.level = alwaysOnTop ? .floating : .normal
                    }) {
                        Image(systemName: alwaysOnTop ? "pin.fill" : "pin.slash")
                            .foregroundColor(alwaysOnTop ? .blue : .gray)
                            .help("Toggle Always on Top")
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: {
                        // First show menu bar and main window
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.showMenuBar()
                            appDelegate.showMainWindow()
                            NSApp.activate(ignoringOtherApps: true)
                        }
                        
                        // Then hide floating window
                        FloatingWindowController.shared.hide()
                        
                        // Update the mode in UserDefaults
                        UserDefaults.standard.set("menuBar", forKey: "preferredInterface")
                    }) {
                        Image(systemName: "gear")
                            .help("Switch to Menu Bar Mode")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.bottom, 4)
                
                Divider()
                
                // Device list
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(pingManager.devices) { device in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(device.isReachable ? Color.green : Color.red)
                                        .frame(width: 8, height: 8)
                                    
                                    Text(device.name)
                                        .font(.system(size: min(max(geometry.size.width * 0.06, 10), 14)))
                                    
                                    Spacer()
                                }
                                
                                if showNotes, let note = device.note, !note.isEmpty {
                                    Text(note)
                                        .font(.system(size: min(max(geometry.size.width * 0.05, 9), 12)))
                                        .foregroundColor(.gray)
                                        .padding(.leading, 16)
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(4)
                        }
                    }
                }
            }
            .padding(8)
        }
        .frame(minWidth: 180, maxWidth: 280)
        .frame(minHeight: 100)
    }
}
