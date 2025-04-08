//
//  MenuBarController.swift
//  MultiPing
//
//  Created by Jamie Metzger on 4/6/25.
//


import Foundation
import AppKit
import SwiftUI

class MenuBarController {
    private var statusItem: NSStatusItem?
    @ObservedObject private var pingManager = PingManager.shared
    
    func start() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateDisplay()
        
        // Start periodic updates
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.pingManager.pingAll { _ in
                self?.updateDisplay()
            }
        }
    }
    
    func hide() {
        statusItem?.isVisible = false
    }
    
    func show() {
        statusItem?.isVisible = true
        updateDisplay()
    }
    
    private func updateDisplay() {
        guard let statusItem = statusItem else { return }
        
        let devicesView = HStack(spacing: 4) {
            ForEach(pingManager.devices) { device in
                HStack(spacing: 2) {
                    Circle()
                        .fill(device.isReachable ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(device.name)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.2))
                .cornerRadius(4)
            }
        }
        .padding(.horizontal, 4)
        
        let hostingView = NSHostingView(rootView: devicesView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 200, height: 22)
        
        statusItem.button?.subviews.forEach { $0.removeFromSuperview() }
        statusItem.button?.addSubview(hostingView)
    }
}
