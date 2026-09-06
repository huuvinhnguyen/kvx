//
//  RelayChannelTests.swift
//  kvxTests
//
//  Created by Developer Agent on 06/09/2026.
//

import XCTest
@testable import kvx

final class RelayChannelTests: XCTestCase {
    func testCreatesInstanceWithRequiredFields() {
        let channel = RelayChannel(index: 0, isOn: true)

        XCTAssertEqual(channel.index, 0)
        XCTAssertTrue(channel.isOn)
        XCTAssertNil(channel.label)
    }

    func testCreatesInstanceWithOptionalLabel() {
        let channel = RelayChannel(index: 1, isOn: false, label: "Máy bơm")

        XCTAssertEqual(channel.index, 1)
        XCTAssertFalse(channel.isOn)
        XCTAssertEqual(channel.label, "Máy bơm")
    }

    func testEqualityBasedOnIndex() {
        let channel1 = RelayChannel(index: 0, isOn: true)
        let channel2 = RelayChannel(index: 0, isOn: false)
        let channel3 = RelayChannel(index: 1, isOn: true)

        XCTAssertEqual(channel1, channel2) // same index
        XCTAssertNotEqual(channel1, channel3) // different index
    }

    func testHashCodeBasedOnIndex() {
        let channel1 = RelayChannel(index: 0, isOn: true)
        let channel2 = RelayChannel(index: 0, isOn: false)
        let channel3 = RelayChannel(index: 1, isOn: true)

        XCTAssertEqual(channel1.hashValue, channel2.hashValue)
        XCTAssertNotEqual(channel1.hashValue, channel3.hashValue)
    }

    func testCodableConformance() throws {
        let original = RelayChannel(index: 2, isOn: true, label: "Test")

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RelayChannel.self, from: data)

        XCTAssertEqual(decoded.index, original.index)
        XCTAssertEqual(decoded.isOn, original.isOn)
        XCTAssertEqual(decoded.label, original.label)
    }
}
