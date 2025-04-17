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
    @EnvironmentObject var appDelegate: AppDelegate
    
    @ObservedObject var pingManager = PingManager.shared
    @State private var alwaysOnTop = UserDefaults.standard.bool(forKey: "alwaysOnTop")
    @State private var showNotes = false
    weak var windowRef: NSWindow?
    
    // Add an observed object constructor that sets up notification handling
    init(windowRef: NSWindow?) {
        print("SimplifiedDeviceView: Initializing with windowRef \(windowRef != nil)")
        self.windowRef = windowRef
        
        // Set up notification observer for device list changes
        NotificationCenter.default.addObserver(forName: .deviceListChanged, object: nil, queue: .main) { _ in
            // This will trigger a view refresh since pingManager is an @ObservedObject
            print("SimplifiedDeviceView: Device list changed notification received")
        }
    }
    
    var body: some View {
        // Add logging
        let _ = print("SimplifiedDeviceView: Computing body. Delegate=\(appDelegate), Devices=\(pingManager.devices.count)")
        
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
                        print("SimplifiedDeviceView: Gear icon clicked - switching to menuBar mode")
                        
                        // First hide this window to prevent visual glitches
                        if let window = windowRef {
                            print("SimplifiedDeviceView: Hiding floating window before mode switch")
                            window.orderOut(nil)
                        }
                        
                        // Then switch mode with a slight delay to ensure window is fully hidden
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            print("SimplifiedDeviceView: Now calling switchMode to menuBar")
                            self.appDelegate.switchMode(to: "menuBar")
                        }
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
        .onAppear {
            print("SimplifiedDeviceView: onAppear called")
        }
        .onDisappear {
            print("SimplifiedDeviceView: onDisappear called")
            // Clean up notification observer when view disappears
            NotificationCenter.default.removeObserver(self)
        }
    }
}
