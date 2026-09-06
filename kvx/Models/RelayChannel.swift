//
//  RelayChannel.swift
//  kvx
//
//  Created by Developer Agent on 06/09/2026.
//

import Foundation

struct RelayChannel: Equatable, Hashable, Codable {
    let index: Int
    let isOn: Bool
    let label: String?

    init(index: Int, isOn: Bool, label: String? = nil) {
        self.index = index
        self.isOn = isOn
        self.label = label
    }

    // Equatable based on index
    static func == (lhs: RelayChannel, rhs: RelayChannel) -> Bool {
        lhs.index == rhs.index
    }

    // Hashable based on index
    func hash(into hasher: inout Hasher) {
        hasher.combine(index)
    }
}
