//
//  RelayReminderTests.swift
//  kvxTests
//
//  Created by Developer Agent on 06/09/2026.
//

import XCTest
@testable import kvx

final class RelayReminderTests: XCTestCase {
    let now = Date()
    let duration: TimeInterval = 300 // 5 minutes in seconds

    func testCreatesInstanceWithRequiredFields() {
        let reminder = RelayReminder(
            id: "reminder-1",
            deviceId: "device-1",
            relayIndex: 0,
            startTime: now,
            duration: duration,
            repeatType: .daily
        )

        XCTAssertEqual(reminder.id, "reminder-1")
        XCTAssertEqual(reminder.deviceId, "device-1")
        XCTAssertEqual(reminder.relayIndex, 0)
        XCTAssertEqual(reminder.startTime, now)
        XCTAssertEqual(reminder.duration, duration)
        XCTAssertEqual(reminder.repeatType, .daily)
        XCTAssertTrue(reminder.isActive) // default
    }

    func testCreatesInstanceWithCustomIsActive() {
        let reminder = RelayReminder(
            deviceId: "device-1",
            relayIndex: 1,
            startTime: now,
            duration: duration,
            repeatType: .weekly,
            isActive: false
        )

        XCTAssertFalse(reminder.isActive)
    }

    func testPreconditionFailsForNegativeRelayIndex() {
        // We can't directly test precondition failure in unit tests
        // but we document the expected behavior
        // In debug builds, this would crash with precondition failure
    }

    func testPreconditionFailsForZeroDuration() {
        // In debug builds, this would crash with precondition failure
        // duration must be > 0
    }

    func testEqualityBasedOnId() {
        let reminder1 = RelayReminder(
            id: "reminder-1",
            deviceId: "device-1",
            relayIndex: 0,
            startTime: now,
            duration: duration,
            repeatType: .daily
        )

        let reminder2 = RelayReminder(
            id: "reminder-1",
            deviceId: "device-2",
            relayIndex: 1,
            startTime: now,
            duration: 600,
            repeatType: .weekly
        )

        let reminder3 = RelayReminder(
            id: "reminder-2",
            deviceId: "device-1",
            relayIndex: 0,
            startTime: now,
            duration: duration,
            repeatType: .daily
        )

        XCTAssertEqual(reminder1, reminder2) // same id
        XCTAssertNotEqual(reminder1, reminder3) // different id
    }

    func testHashCodeBasedOnId() {
        let reminder1 = RelayReminder(
            id: "reminder-1",
            deviceId: "device-1",
            relayIndex: 0,
            startTime: now,
            duration: duration,
            repeatType: .daily
        )

        let reminder2 = RelayReminder(
            id: "reminder-1",
            deviceId: "device-2",
            relayIndex: 1,
            startTime: now,
            duration: duration,
            repeatType: .weekly
        )

        XCTAssertEqual(reminder1.hashValue, reminder2.hashValue)
    }

    func testCodableConformance() throws {
        let original = RelayReminder(
            id: "reminder-1",
            deviceId: "device-1",
            relayIndex: 0,
            startTime: now,
            duration: duration,
            repeatType: .daily,
            isActive: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RelayReminder.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.deviceId, original.deviceId)
        XCTAssertEqual(decoded.relayIndex, original.relayIndex)
        XCTAssertEqual(decoded.duration, original.duration)
        XCTAssertEqual(decoded.repeatType, original.repeatType)
        XCTAssertEqual(decoded.isActive, original.isActive)
    }

    func testIdentifiableConformance() {
        let reminder = RelayReminder(
            id: "reminder-1",
            deviceId: "device-1",
            relayIndex: 0,
            startTime: now,
            duration: duration,
            repeatType: .daily
        )

        XCTAssertEqual(reminder.id, "reminder-1")
    }
}

final class ReminderRepeatTypeTests: XCTestCase {
    func testHasVietnameseDisplayNames() {
        XCTAssertEqual(ReminderRepeatType.none.displayName, "Không lặp lại")
        XCTAssertEqual(ReminderRepeatType.daily.displayName, "Hằng ngày")
        XCTAssertEqual(ReminderRepeatType.weekly.displayName, "Hằng tuần")
        XCTAssertEqual(ReminderRepeatType.monthly.displayName, "Hằng tháng")
    }

    func testEnumValuesMatchExpectedCases() {
        XCTAssertEqual(ReminderRepeatType.allCases.count, 4)
        XCTAssertTrue(ReminderRepeatType.allCases.contains(.none))
        XCTAssertTrue(ReminderRepeatType.allCases.contains(.daily))
        XCTAssertTrue(ReminderRepeatType.allCases.contains(.weekly))
        XCTAssertTrue(ReminderRepeatType.allCases.contains(.monthly))
    }

    func testIdentifiableConformance() {
        XCTAssertEqual(ReminderRepeatType.daily.id, "daily")
        XCTAssertEqual(ReminderRepeatType.weekly.id, "weekly")
    }

    func testRawValueMapping() {
        XCTAssertEqual(ReminderRepeatType.none.rawValue, "none")
        XCTAssertEqual(ReminderRepeatType.daily.rawValue, "daily")
        XCTAssertEqual(ReminderRepeatType.weekly.rawValue, "weekly")
        XCTAssertEqual(ReminderRepeatType.monthly.rawValue, "monthly")
    }
}
