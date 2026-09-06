//
//  RelayStatisticsTests.swift
//  kvxTests
//
//  Created by Developer Agent on 06/09/2026.
//

import XCTest
@testable import kvx

final class RelayStatisticsTests: XCTestCase {
    func testCreatesInstanceWithRequiredFields() {
        let statistics = RelayStatistics(
            deviceId: "device-1",
            relayIndex: 0,
            totalOnTime: 9000, // 2.5 hours in seconds
            activationCount: 15
        )

        XCTAssertEqual(statistics.deviceId, "device-1")
        XCTAssertEqual(statistics.relayIndex, 0)
        XCTAssertEqual(statistics.totalOnTime, 9000)
        XCTAssertEqual(statistics.activationCount, 15)
        XCTAssertNil(statistics.lastActivated)
    }

    func testCreatesInstanceWithOptionalLastActivated() {
        let lastActivated = Date()
        let statistics = RelayStatistics(
            deviceId: "device-1",
            relayIndex: 1,
            totalOnTime: 2700, // 45 minutes
            activationCount: 8,
            lastActivated: lastActivated
        )

        XCTAssertEqual(statistics.lastActivated, lastActivated)
    }

    func testEqualityBasedOnDeviceIdAndRelayIndex() {
        let statistics1 = RelayStatistics(
            deviceId: "device-1",
            relayIndex: 0,
            totalOnTime: 600,
            activationCount: 5
        )

        let statistics2 = RelayStatistics(
            deviceId: "device-1",
            relayIndex: 0,
            totalOnTime: 7200,
            activationCount: 20
        )

        let statistics3 = RelayStatistics(
            deviceId: "device-1",
            relayIndex: 1,
            totalOnTime: 600,
            activationCount: 5
        )

        let statistics4 = RelayStatistics(
            deviceId: "device-2",
            relayIndex: 0,
            totalOnTime: 600,
            activationCount: 5
        )

        XCTAssertEqual(statistics1, statistics2) // same deviceId and relayIndex
        XCTAssertNotEqual(statistics1, statistics3) // different relayIndex
        XCTAssertNotEqual(statistics1, statistics4) // different deviceId
    }

    func testHashCodeBasedOnDeviceIdAndRelayIndex() {
        let statistics1 = RelayStatistics(
            deviceId: "device-1",
            relayIndex: 0,
            totalOnTime: 600,
            activationCount: 5
        )

        let statistics2 = RelayStatistics(
            deviceId: "device-1",
            relayIndex: 0,
            totalOnTime: 7200,
            activationCount: 20
        )

        let statistics3 = RelayStatistics(
            deviceId: "device-1",
            relayIndex: 1,
            totalOnTime: 600,
            activationCount: 5
        )

        XCTAssertEqual(statistics1.hashValue, statistics2.hashValue)
        XCTAssertNotEqual(statistics1.hashValue, statistics3.hashValue)
    }

    func testSupportsZeroActivationCount() {
        let statistics = RelayStatistics(
            deviceId: "device-1",
            relayIndex: 0,
            totalOnTime: 0,
            activationCount: 0
        )

        XCTAssertEqual(statistics.activationCount, 0)
        XCTAssertEqual(statistics.totalOnTime, 0)
    }

    func testCodableConformance() throws {
        let lastActivated = Date()
        let original = RelayStatistics(
            deviceId: "device-1",
            relayIndex: 2,
            totalOnTime: 3600,
            activationCount: 12,
            lastActivated: lastActivated
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RelayStatistics.self, from: data)

        XCTAssertEqual(decoded.deviceId, original.deviceId)
        XCTAssertEqual(decoded.relayIndex, original.relayIndex)
        XCTAssertEqual(decoded.totalOnTime, original.totalOnTime)
        XCTAssertEqual(decoded.activationCount, original.activationCount)
        XCTAssertEqual(decoded.lastActivated?.timeIntervalSince1970,
                       original.lastActivated?.timeIntervalSince1970)
    }
}
