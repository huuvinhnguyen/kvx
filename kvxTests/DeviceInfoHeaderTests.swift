import XCTest
import SwiftUI
@testable import kvx

final class DeviceInfoHeaderTests: XCTestCase {

    func testHeaderCreation() {
        let header = DeviceInfoHeader(deviceName: "esp8266_11729385")
        XCTAssertNotNil(header)
    }

    func testHeaderWithLastConnected() {
        let header = DeviceInfoHeader(
            deviceName: "esp8266_11729385",
            lastConnected: Date()
        )
        XCTAssertNotNil(header)
    }

    func testHeaderWithVersions() {
        let header = DeviceInfoHeader(
            deviceName: "esp8266_11729385",
            firmwareVersion: "0",
            appVersion: "1.0.0"
        )
        XCTAssertNotNil(header)
    }

    func testHeaderWithRefreshCallback() {
        var refreshCalled = false
        let header = DeviceInfoHeader(
            deviceName: "esp8266_11729385",
            onRefresh: {
                refreshCalled = true
            }
        )

        XCTAssertNotNil(header)
        XCTAssertFalse(refreshCalled)
    }

    func testHeaderWithLoadingState() {
        let header = DeviceInfoHeader(
            deviceName: "esp8266_11729385",
            onRefresh: {},
            isLoading: true
        )
        XCTAssertNotNil(header)
    }

    func testHeaderWithAllProperties() {
        let header = DeviceInfoHeader(
            deviceName: "esp8266_11729385",
            lastConnected: Date(),
            firmwareVersion: "0",
            appVersion: "1.0.0",
            onRefresh: {},
            isLoading: false
        )
        XCTAssertNotNil(header)
    }
}
