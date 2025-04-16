//
//  ModeSelectorWindowController.swift
//  MultiPing
//
//  Created by Jamie Metzger on 4/6/25.
//


import Cocoa
import SwiftUI

class ModeSelectorWindowController: NSWindowController {
    static let shared = ModeSelectorWindowController()

    private init() {
        print("ModeSelectorWindowController initialized")
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Choose Interface Mode"

        super.init(window: window)
        window.contentView = NSHostingView(rootView: ModeSelectorView(closeHandler: {
            self.window?.close()
        }))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        print("Showing Mode Selector Window")
        self.showWindow(nil)
        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)
    }
}

class ModeSelection: ObservableObject {
    @Published var selectedMode: String {
        didSet {
            UserDefaults.standard.set(selectedMode, forKey: "preferredInterface")
        }
    }
    
    init() {
        selectedMode = UserDefaults.standard.string(forKey: "preferredInterface") ?? "menuBar"
    }
}

struct ModeSelectorView: View {
    let closeHandler: () -> Void
    @StateObject private var modeSelection = ModeSelection()
    private let modes = ["menuBar", "floatingWindow", "cli"]

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Choose how Multi-Ping should run:")
                .font(.headline)

            Picker("Interface Mode", selection: $modeSelection.selectedMode) {
                Text("Menu Bar").tag("menuBar")
                Text("Floating Window").tag("floatingWindow")
                Text("Command Line").tag("cli")
            }
            .pickerStyle(.inline)
            .onChange(of: modeSelection.selectedMode) { newMode in
                closeHandler()
                switch newMode {
                case "menuBar":
                    MenuBarController.shared.setup(with: PingManager.shared)
                case "floatingWindow":
                    // FloatingWindowController.shared.show() // Commented out: Missing appDelegate argument
                    print("ModeSelectorView: Floating window mode selected, but show() needs appDelegate.")
                    // Need to get AppDelegate instance here to pass
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                         appDelegate.switchMode(to: newMode) // Use switchMode instead for consistency
                    } else {
                         print("ModeSelectorView: ERROR - Could not get AppDelegate to switch mode.")
                    }
                case "cli":
                    print("CLI mode selected - CLI runner not implemented yet.")
                default:
                    break
                }
            }

            Spacer()
        }
        .padding()
        .frame(width: 280)
    }
}
