//
//  EnvironmentalSensorRepository.swift
//  kvx
//
//  Created by Vinh Nguyen on 5/9/26.
//

import Foundation

/// Repository contract for observing environmental sensor readings.
///
/// Implementations may connect to local simulators, remote APIs, WebSocket streams,
/// MQTT topics, Bluetooth sensors, or other hardware sources.
///
/// The repository must:
/// - Emit readings asynchronously in a non-blocking manner
/// - Scope events to the requested stable device ID
/// - Support cooperative cancellation
/// - Surface terminal failures distinctly from waiting/no-reading states
protocol EnvironmentalSensorRepository {
    /// Observes environmental readings for the specified device.
    ///
    /// The returned stream emits reading events until cancelled or until the source fails.
    /// Events are scoped to the requested device ID.
    ///
    /// - Parameter deviceId: Stable device identifier
    /// - Returns: AsyncThrowingStream of environmental readings
    /// - Throws: `EnvironmentalSensorError` when the source fails terminally
    func observeReadings(deviceId: String) -> AsyncThrowingStream<EnvironmentalReading, Error>
}

/// Errors that can occur when observing environmental sensor readings.
enum EnvironmentalSensorError: Error, Equatable {
    /// The source is unavailable or disconnected.
    case sourceUnavailable

    /// The device ID was not found or is not a valid environmental sensor.
    case deviceNotFound(String)

    /// An event was malformed and could not be parsed.
    case malformedEvent

    /// The observation was cancelled.
    case cancelled
}
