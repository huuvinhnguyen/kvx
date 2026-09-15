import XCTest
import SwiftUI
@testable import kvx

final class DeviceControlFooterTests: XCTestCase {

    func testFooterCreation() {
        let footer = DeviceControlFooter(deviceId: "esp8266_11729385")
        XCTAssertNotNil(footer)
    }

    func testFooterWithVersions() {
        let footer = DeviceControlFooter(
            deviceId: "esp8266_11729385",
            firmwareVersion: "0",
            appVersion: "1.0.0"
        )
        XCTAssertNotNil(footer)
    }

    func testFooterWithRestartCallback() {
        var restartCalled = false
        let footer = DeviceControlFooter(
            deviceId: "esp8266_11729385",
            onRestart: {
                restartCalled = true
            }
        )

        XCTAssertNotNil(footer)
        XCTAssertFalse(restartCalled)
    }

    func testFooterWithResetWifiCallback() {
        var resetWifiCalled = false
        let footer = DeviceControlFooter(
            deviceId: "esp8266_11729385",
            onResetWifi: {
                resetWifiCalled = true
            }
        )

        XCTAssertNotNil(footer)
        XCTAssertFalse(resetWifiCalled)
    }

    func testFooterWithLoadingState() {
        let footer = DeviceControlFooter(
            deviceId: "esp8266_11729385",
            onRestart: {},
            onResetWifi: {},
            isLoading: true
        )
        XCTAssertNotNil(footer)
    }

    func testFooterWithAllProperties() {
        let footer = DeviceControlFooter(
            deviceId: "esp8266_11729385",
            firmwareVersion: "0",
            appVersion: "1.0.0",
            onRestart: {},
            onResetWifi: {},
            isLoading: false
        )
        XCTAssertNotNil(footer)
    }
}
