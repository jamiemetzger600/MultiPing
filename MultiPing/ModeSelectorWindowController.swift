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

struct ModeSelectorView: View {
    let closeHandler: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Choose how Multi-Ping should run:")
                .font(.headline)

            ForEach(["menuBar", "floatingWindow", "cli"], id: \.self) { mode in
                Button(action: {
                    UserDefaults.standard.set(mode, forKey: "preferredInterface")
                    closeHandler()
                    switch mode {
                    case "menuBar":
                        MenuBarController().start()
                    case "floatingWindow":
                        FloatingWindowController().show()
                    case "cli":
                        print("CLI mode selected - CLI runner not implemented yet.")
                    default:
                        break
                    }
                }) {
                    Text(modeDisplayName(for: mode))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding()
        .frame(width: 280)
    }

    private func modeDisplayName(for mode: String) -> String {
        switch mode {
        case "menuBar": return "Menu Bar"
        case "floatingWindow": return "Floating Window"
        case "cli": return "Command Line (CLI)"
        default: return mode
        }
    }
}
