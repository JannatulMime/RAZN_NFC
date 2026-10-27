//
//  SemanticVersionTests.swift
//  RAZN NFCTests
//

import XCTest
@testable import RAZN_NFC

final class SemanticVersionTests: XCTestCase {
    func testParsesMajorMinor() {
        let version = SemanticVersion(string: "5.0")
        XCTAssertEqual(version?.components, [5, 0])
    }

    func testParsesThreeComponents() {
        let version = SemanticVersion(string: "1.10.0")
        XCTAssertEqual(version?.components, [1, 10, 0])
    }

    func testOneTenIsNewerThanOneTwo() {
        let newer = SemanticVersion(string: "1.10.0")
        let older = SemanticVersion(string: "1.2.0")
        XCTAssertNotNil(newer)
        XCTAssertNotNil(older)
        XCTAssertTrue(newer! > older!)
        XCTAssertTrue(older! < newer!)
    }

    func testPaddingTreatsFiveZeroEqualToFiveZeroZero() {
        let a = SemanticVersion(string: "5.0")
        let b = SemanticVersion(string: "5.0.0")
        XCTAssertEqual(a, b)
        XCTAssertFalse(a! < b!)
        XCTAssertFalse(b! < a!)
    }

    func testTwoIsNewerThanOne() {
        let two = SemanticVersion(string: "2.0.0")!
        let one = SemanticVersion(string: "1.9.9")!
        XCTAssertTrue(two > one)
    }

    func testRejectsInvalidStrings() {
        XCTAssertNil(SemanticVersion(string: ""))
        XCTAssertNil(SemanticVersion(string: "   "))
        XCTAssertNil(SemanticVersion(string: "1.2.beta"))
        XCTAssertNil(SemanticVersion(string: "1..2"))
        XCTAssertNil(SemanticVersion(string: "abc"))
        XCTAssertNil(SemanticVersion(string: "1.2."))
    }

    func testTrimsWhitespace() {
        XCTAssertEqual(SemanticVersion(string: " 1.2.3 "), SemanticVersion(string: "1.2.3"))
    }
}
