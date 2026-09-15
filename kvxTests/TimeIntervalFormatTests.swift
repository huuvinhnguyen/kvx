import XCTest
@testable import kvx

final class TimeIntervalFormatTests: XCTestCase {

    func testVietnameseStringForSeconds() {
        let duration: TimeInterval = 30
        XCTAssertEqual(duration.toVietnameseString, "30 giây")
    }

    func testVietnameseStringForMinutes() {
        let duration: TimeInterval = 120 // 2 minutes
        XCTAssertEqual(duration.toVietnameseString, "2 phút")
    }

    func testVietnameseStringForHours() {
        let duration: TimeInterval = 3600 // 1 hour
        XCTAssertEqual(duration.toVietnameseString, "1 giờ")
    }

    func testVietnameseStringForMixedDuration() {
        let duration: TimeInterval = 3690 // 1 hour, 1 minute, 30 seconds
        XCTAssertEqual(duration.toVietnameseString, "1 giờ 1 phút 30 giây")
    }

    func testVietnameseStringForZero() {
        let duration: TimeInterval = 0
        XCTAssertEqual(duration.toVietnameseString, "0 giây")
    }

    func testCompactStringForSeconds() {
        let duration: TimeInterval = 30
        XCTAssertEqual(duration.toCompactString, "30s")
    }

    func testCompactStringForMinutes() {
        let duration: TimeInterval = 120 // 2 minutes
        XCTAssertEqual(duration.toCompactString, "2m")
    }

    func testCompactStringForHours() {
        let duration: TimeInterval = 3600 // 1 hour
        XCTAssertEqual(duration.toCompactString, "1h")
    }

    func testCompactStringForMixedDuration() {
        let duration: TimeInterval = 3690 // 1 hour, 1 minute, 30 seconds
        XCTAssertEqual(duration.toCompactString, "1h 1m 30s")
    }

    func testCompactStringForZero() {
        let duration: TimeInterval = 0
        XCTAssertEqual(duration.toCompactString, "0s")
    }

    func testVietnameseStringForMinutesAndSeconds() {
        let duration: TimeInterval = 90 // 1 minute, 30 seconds
        XCTAssertEqual(duration.toVietnameseString, "1 phút 30 giây")
    }

    func testCompactStringForMinutesAndSeconds() {
        let duration: TimeInterval = 90 // 1 minute, 30 seconds
        XCTAssertEqual(duration.toCompactString, "1m 30s")
    }
}
