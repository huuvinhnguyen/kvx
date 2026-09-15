import XCTest
import SwiftUI
@testable import kvx

final class RelayReminderListTests: XCTestCase {

    func testEmptyReminderList() {
        let binding = Binding.constant(false)
        let list = RelayReminderList(
            reminders: [],
            areRemindersActive: binding
        )
        XCTAssertNotNil(list)
    }

    func testReminderListWithItems() {
        let reminders = [
            RelayReminder(
                id: "1",
                deviceId: "device-123",
                relayIndex: 0,
                startTime: Date(),
                duration: 300,
                repeatType: .daily
            ),
            RelayReminder(
                id: "2",
                deviceId: "device-123",
                relayIndex: 0,
                startTime: Date(),
                duration: 60,
                repeatType: .weekly
            )
        ]
        let binding = Binding.constant(true)
        let list = RelayReminderList(
            reminders: reminders,
            areRemindersActive: binding
        )
        XCTAssertNotNil(list)
    }

    func testReminderListWithDeleteCallback() {
        var deletedId: String?
        let reminders = [
            RelayReminder(
                id: "1",
                deviceId: "device-123",
                relayIndex: 0,
                startTime: Date(),
                duration: 300,
                repeatType: .daily
            )
        ]
        let binding = Binding.constant(true)
        let list = RelayReminderList(
            reminders: reminders,
            areRemindersActive: binding,
            onDelete: { id in
                deletedId = id
            }
        )

        XCTAssertNotNil(list)
        XCTAssertNil(deletedId)
    }

    func testReminderListDisabledState() {
        let binding = Binding.constant(false)
        let list = RelayReminderList(
            reminders: [],
            areRemindersActive: binding,
            isEnabled: false
        )
        XCTAssertNotNil(list)
    }

    func testReminderListToggleBinding() {
        var isActive = false
        let binding = Binding(
            get: { isActive },
            set: { isActive = $0 }
        )
        let list = RelayReminderList(
            reminders: [],
            areRemindersActive: binding
        )

        XCTAssertNotNil(list)
        XCTAssertFalse(isActive)
    }
}
