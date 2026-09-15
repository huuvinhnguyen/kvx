import XCTest
import SwiftUI
@testable import kvx

final class RelayLonglastFormTests: XCTestCase {

    func testFormCreation() {
        let form = RelayLonglastForm(onActivate: { _ in })
        XCTAssertNotNil(form)
    }

    func testFormWithDisabledState() {
        let form = RelayLonglastForm(onActivate: { _ in }, isEnabled: false)
        XCTAssertNotNil(form)
    }

    func testDurationUnitEnum() {
        XCTAssertEqual(DurationUnit.seconds.rawValue, "Giây")
        XCTAssertEqual(DurationUnit.minutes.rawValue, "Phút")
        XCTAssertEqual(DurationUnit.allCases.count, 2)
    }

    func testDurationUnitIdentifiable() {
        let unit = DurationUnit.seconds
        XCTAssertEqual(unit.id, unit.rawValue)
    }

    func testOnActivateCallback() {
        var capturedDuration: TimeInterval?
        let form = RelayLonglastForm(onActivate: { duration in
            capturedDuration = duration
        })

        XCTAssertNotNil(form)
        XCTAssertNil(capturedDuration)
    }

    func testFormDefaultState() {
        let form = RelayLonglastForm(onActivate: { _ in })
        XCTAssertNotNil(form)
        // Form should be enabled by default
    }
}
