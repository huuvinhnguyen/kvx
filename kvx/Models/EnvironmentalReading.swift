//
//  EnvironmentalReading.swift
//  kvx
//
//  Created by Vinh Nguyen on 5/9/26.
//

import Foundation

/// Represents a temperature and/or humidity measurement from an environmental sensor.
///
/// Domain entity for sensor readings. Does not depend on UI, network, persistence, or hardware SDKs.
/// Temperature is stored canonically in degrees Celsius.
/// Relative humidity is stored as a percentage (0...100).
struct EnvironmentalReading: Equatable {
    /// The stable device identifier this reading came from.
    let deviceId: String

    /// Temperature in degrees Celsius, or nil if not available.
    let temperatureCelsius: Double?

    /// Relative humidity as a percentage (0...100), or nil if not available.
    let relativeHumidityPercent: Double?

    /// The time at which the sensor measured this reading.
    let measuredAt: Date

    /// Creates an environmental reading.
    ///
    /// - Parameters:
    ///   - deviceId: Stable device identifier; must not be empty.
    ///   - temperatureCelsius: Temperature in °C; must be finite when present.
    ///   - relativeHumidityPercent: Humidity percentage; must be finite and within 0...100 when present.
    ///   - measuredAt: Sensor measurement timestamp.
    init(
        deviceId: String,
        temperatureCelsius: Double?,
        relativeHumidityPercent: Double?,
        measuredAt: Date
    ) {
        precondition(!deviceId.isEmpty, "deviceId must not be empty")

        if let temp = temperatureCelsius {
            precondition(temp.isFinite, "temperatureCelsius must be finite")
        }

        if let humidity = relativeHumidityPercent {
            precondition(humidity.isFinite && humidity >= 0 && humidity <= 100,
                        "relativeHumidityPercent must be finite and within 0...100")
        }

        self.deviceId = deviceId
        self.temperatureCelsius = temperatureCelsius
        self.relativeHumidityPercent = relativeHumidityPercent
        self.measuredAt = measuredAt
    }

    /// Returns true if this reading has at least one valid metric.
    var hasData: Bool {
        temperatureCelsius != nil || relativeHumidityPercent != nil
    }

    /// Returns true if both temperature and humidity are present.
    var isComplete: Bool {
        temperatureCelsius != nil && relativeHumidityPercent != nil
    }

    /// Returns true if this is a partial reading (only one metric present).
    var isPartial: Bool {
        hasData && !isComplete
    }
}

// MARK: - Sample Data

extension EnvironmentalReading {
    /// Sample readings for previews and tests.
    static let samples: [EnvironmentalReading] = [
        // Full reading
        EnvironmentalReading(
            deviceId: "sensor-001",
            temperatureCelsius: 24.5,
            relativeHumidityPercent: 58.0,
            measuredAt: Date()
        ),

        // Temperature only
        EnvironmentalReading(
            deviceId: "sensor-002",
            temperatureCelsius: 22.0,
            relativeHumidityPercent: nil,
            measuredAt: Date()
        ),

        // Humidity only
        EnvironmentalReading(
            deviceId: "sensor-003",
            temperatureCelsius: nil,
            relativeHumidityPercent: 65.0,
            measuredAt: Date()
        ),

        // Stale reading (5+ minutes old)
        EnvironmentalReading(
            deviceId: "sensor-004",
            temperatureCelsius: 26.0,
            relativeHumidityPercent: 52.0,
            measuredAt: Date().addingTimeInterval(-400)
        )
    ]
}
