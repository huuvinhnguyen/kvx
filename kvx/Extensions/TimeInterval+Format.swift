import Foundation

/// Extension for formatting TimeInterval (duration) values
/// Matches Flutter's DurationExtension
extension TimeInterval {
    /// Format duration as human-readable Vietnamese string
    /// Examples:
    /// - 30 seconds -> "30 giây"
    /// - 90 seconds -> "1 phút 30 giây"
    /// - 3600 seconds -> "1 giờ"
    var toVietnameseString: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        var parts: [String] = []

        if hours > 0 {
            parts.append("\(hours) giờ")
        }

        if minutes > 0 {
            parts.append("\(minutes) phút")
        }

        if seconds > 0 || parts.isEmpty {
            parts.append("\(seconds) giây")
        }

        return parts.joined(separator: " ")
    }

    /// Format duration as compact string
    /// Examples:
    /// - 30 seconds -> "30s"
    /// - 90 seconds -> "1m 30s"
    /// - 3600 seconds -> "1h"
    var toCompactString: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        var parts: [String] = []

        if hours > 0 {
            parts.append("\(hours)h")
        }

        if minutes > 0 {
            parts.append("\(minutes)m")
        }

        if seconds > 0 || parts.isEmpty {
            parts.append("\(seconds)s")
        }

        return parts.joined(separator: " ")
    }
}
