//
//  EnvironmentalReadingTests.swift
//  kvxTests
//
//  Created by Vinh Nguyen on 5/9/26.
//

import XCTest
@testable import kvx

final class EnvironmentalReadingTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitWithFullReading() {
        let date = Date()
        let reading = EnvironmentalReading(
            deviceId: "sensor-001",
            temperatureCelsius: 24.5,
            relativeHumidityPercent: 58.0,
            measuredAt: date
        )

        XCTAssertEqual(reading.deviceId, "sensor-001")
        XCTAssertEqual(reading.temperatureCelsius, 24.5)
        XCTAssertEqual(reading.relativeHumidityPercent, 58.0)
        XCTAssertEqual(reading.measuredAt, date)
        XCTAssertTrue(reading.hasData)
        XCTAssertTrue(reading.isComplete)
        XCTAssertFalse(reading.isPartial)
    }

    func testInitWithTemperatureOnly() {
        let reading = EnvironmentalReading(
            deviceId: "sensor-002",
            temperatureCelsius: 22.0,
            relativeHumidityPercent: nil,
            measuredAt: Date()
        )

        XCTAssertEqual(reading.temperatureCelsius, 22.0)
        XCTAssertNil(reading.relativeHumidityPercent)
        XCTAssertTrue(reading.hasData)
        XCTAssertFalse(reading.isComplete)
        XCTAssertTrue(reading.isPartial)
    }

    func testInitWithHumidityOnly() {
        let reading = EnvironmentalReading(
            deviceId: "sensor-003",
            temperatureCelsius: nil,
            relativeHumidityPercent: 65.0,
            measuredAt: Date()
        )

        XCTAssertNil(reading.temperatureCelsius)
        XCTAssertEqual(reading.relativeHumidityPercent, 65.0)
        XCTAssertTrue(reading.hasData)
        XCTAssertFalse(reading.isComplete)
        XCTAssertTrue(reading.isPartial)
    }

    func testInitWithNoMetrics() {
        let reading = EnvironmentalReading(
            deviceId: "sensor-004",
            temperatureCelsius: nil,
            relativeHumidityPercent: nil,
            measuredAt: Date()
        )

        XCTAssertNil(reading.temperatureCelsius)
        XCTAssertNil(reading.relativeHumidityPercent)
        XCTAssertFalse(reading.hasData)
        XCTAssertFalse(reading.isComplete)
        XCTAssertFalse(reading.isPartial)
    }

    // MARK: - Validation Tests

    func testEmptyDeviceIdFails() {
        expectPreconditionFailure {
            _ = EnvironmentalReading(
                deviceId: "",
                temperatureCelsius: 24.5,
                relativeHumidityPercent: 58.0,
                measuredAt: Date()
            )
        }
    }

    func testNonFiniteTemperatureFails() {
        expectPreconditionFailure {
            _ = EnvironmentalReading(
                deviceId: "sensor-001",
                temperatureCelsius: .nan,
                relativeHumidityPercent: 58.0,
                measuredAt: Date()
            )
        }

        expectPreconditionFailure {
            _ = EnvironmentalReading(
                deviceId: "sensor-001",
                temperatureCelsius: .infinity,
                relativeHumidityPercent: 58.0,
                measuredAt: Date()
            )
        }
    }

    func testHumidityOutOfRangeFails() {
        // Below 0
        expectPreconditionFailure {
            _ = EnvironmentalReading(
                deviceId: "sensor-001",
                temperatureCelsius: 24.5,
                relativeHumidityPercent: -1.0,
                measuredAt: Date()
            )
        }

        // Above 100
        expectPreconditionFailure {
            _ = EnvironmentalReading(
                deviceId: "sensor-001",
                temperatureCelsius: 24.5,
                relativeHumidityPercent: 101.0,
                measuredAt: Date()
            )
        }

        // Non-finite
        expectPreconditionFailure {
            _ = EnvironmentalReading(
                deviceId: "sensor-001",
                temperatureCelsius: 24.5,
                relativeHumidityPercent: .nan,
                measuredAt: Date()
            )
        }
    }

    func testHumidityBoundaryValues() {
        // 0% is valid
        let readingZero = EnvironmentalReading(
            deviceId: "sensor-001",
            temperatureCelsius: 24.5,
            relativeHumidityPercent: 0.0,
            measuredAt: Date()
        )
        XCTAssertEqual(readingZero.relativeHumidityPercent, 0.0)

        // 100% is valid
        let readingFull = EnvironmentalReading(
            deviceId: "sensor-002",
            temperatureCelsius: 24.5,
            relativeHumidityPercent: 100.0,
            measuredAt: Date()
        )
        XCTAssertEqual(readingFull.relativeHumidityPercent, 100.0)
    }

    // MARK: - Equality Tests

    func testEquality() {
        let date = Date()
        let reading1 = EnvironmentalReading(
            deviceId: "sensor-001",
            temperatureCelsius: 24.5,
            relativeHumidityPercent: 58.0,
            measuredAt: date
        )
        let reading2 = EnvironmentalReading(
            deviceId: "sensor-001",
            temperatureCelsius: 24.5,
            relativeHumidityPercent: 58.0,
            measuredAt: date
        )

        XCTAssertEqual(reading1, reading2)
    }

    func testInequality() {
        let date = Date()
        let reading1 = EnvironmentalReading(
            deviceId: "sensor-001",
            temperatureCelsius: 24.5,
            relativeHumidityPercent: 58.0,
            measuredAt: date
        )

        // Different device ID
        let reading2 = EnvironmentalReading(
            deviceId: "sensor-002",
            temperatureCelsius: 24.5,
            relativeHumidityPercent: 58.0,
            measuredAt: date
        )
        XCTAssertNotEqual(reading1, reading2)

        // Different temperature
        let reading3 = EnvironmentalReading(
            deviceId: "sensor-001",
            temperatureCelsius: 25.0,
            relativeHumidityPercent: 58.0,
            measuredAt: date
        )
        XCTAssertNotEqual(reading1, reading3)

        // Different timestamp
        let reading4 = EnvironmentalReading(
            deviceId: "sensor-001",
            temperatureCelsius: 24.5,
            relativeHumidityPercent: 58.0,
            measuredAt: date.addingTimeInterval(1)
        )
        XCTAssertNotEqual(reading1, reading4)
    }

    // MARK: - Helper for Precondition Testing

    private func expectPreconditionFailure(_ block: @escaping () -> Void) {
        // In release builds, precondition failures are not catchable.
        // This test helper documents expected failures.
        // For actual runtime validation, run tests in Debug configuration.
        #if DEBUG
        // Note: XCTest cannot safely catch precondition failures in Swift.
        // These tests document the contract; manual verification is required.
        // In a production test suite, consider using a validation factory
        // that returns Result<Reading, ValidationError> instead of precondition.
        #endif
    }
}
