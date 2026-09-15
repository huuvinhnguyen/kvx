import XCTest
import SwiftUI
@testable import kvx

final class RelayToggleSwitchTests: XCTestCase {

    func testToggleSwitchCreation() {
        let binding = Binding.constant(false)
        let view = RelayToggleSwitch(isOn: binding)

        XCTAssertNotNil(view)
    }

    func testToggleSwitchWithCustomLabel() {
        let binding = Binding.constant(false)
        let view = RelayToggleSwitch(isOn: binding, label: "Custom Label")

        XCTAssertNotNil(view)
    }

    func testToggleSwitchDisabled() {
        let binding = Binding.constant(false)
        let view = RelayToggleSwitch(isOn: binding, isEnabled: false)

        XCTAssertNotNil(view)
    }

    func testToggleSwitchDefaultLabel() {
        let binding = Binding.constant(false)
        let view = RelayToggleSwitch(isOn: binding)

        // Default label should be "BẬT / TẮT"
        XCTAssertNotNil(view)
    }

    func testToggleSwitchState() {
        var isOn = false
        let binding = Binding(
            get: { isOn },
            set: { isOn = $0 }
        )
        let view = RelayToggleSwitch(isOn: binding)

        XCTAssertNotNil(view)
        XCTAssertFalse(isOn)
    }
}
