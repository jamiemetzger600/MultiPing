//
//  Device.swift
//  MultiPing
//
//  Created by Jamie Metzger on 4/6/25.
//


import Foundation

struct Device: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var ipAddress: String
    var note: String?
    var isReachable: Bool = false

    init(id: UUID = UUID(), name: String, ipAddress: String, note: String? = nil) {
        self.id = id
        self.name = name
        self.ipAddress = ipAddress
        self.note = note
    }
}
