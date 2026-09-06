//
//  ReminderRepeatType.swift
//  kvx
//
//  Created by Developer Agent on 06/09/2026.
//

import Foundation

enum ReminderRepeatType: String, CaseIterable, Codable, Identifiable {
    case none
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Không lặp lại"
        case .daily: return "Hằng ngày"
        case .weekly: return "Hằng tuần"
        case .monthly: return "Hằng tháng"
        }
    }
}
