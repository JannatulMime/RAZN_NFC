//
//  AuthNFCCredentialDerivationTests.swift
//  RAZN NFCTests
//
//  Deterministic HMAC derivation tests. Never uses a production master key.
//

import XCTest
@testable import RAZN_NFC

final class AuthNFCCredentialDerivationTests: XCTestCase {

    /// Documented test-only key (same as AuthNFCMasterKeyProvider.testOnlyMasterKeyHex).
    private let testKeyHex = AuthNFCMasterKeyProvider.testOnlyMasterKeyHex
    private let sampleUID: [UInt8] = [0x04, 0xDE, 0xAD, 0xBE, 0xEF, 0x01, 0x02]

    // Independently computed with Python hmac SHA-256:
    // PWD digest … → 6d4105a4 ; PACK digest … → df86
    private let expectedPWD: [UInt8] = [0x6D, 0x41, 0x05, 0xA4]
    private let expectedPACK: [UInt8] = [0xDF, 0x86]

    func testSameUIDAndKeyProduceSamePassword() throws {
        let key = try BundleAuthNFCMasterKeyProvider.parseMasterKeyHex(testKeyHex)
        let a = try AuthNFCCredentialDerivation.deriveCredentials(uid: sampleUID, masterKey: key)
        let b = try AuthNFCCredentialDerivation.deriveCredentials(uid: sampleUID, masterKey: key)
        XCTAssertEqual(a.password, b.password)
        XCTAssertEqual(a.pack, b.pack)
        XCTAssertEqual(a.password, expectedPWD)
        XCTAssertEqual(a.pack, expectedPACK)
    }

    func testDifferentUIDsProduceDifferentPasswords() throws {
        let key = try BundleAuthNFCMasterKeyProvider.parseMasterKeyHex(testKeyHex)
        let otherUID: [UInt8] = [0x04, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66]
        let a = try AuthNFCCredentialDerivation.deriveCredentials(uid: sampleUID, masterKey: key)
        let b = try AuthNFCCredentialDerivation.deriveCredentials(uid: otherUID, masterKey: key)
        XCTAssertNotEqual(a.password, b.password)
    }

    func testResultsStableAcrossCalls() throws {
        let key = try BundleAuthNFCMasterKeyProvider.parseMasterKeyHex(testKeyHex)
        var results: [[UInt8]] = []
        for _ in 0..<5 {
            let creds = try AuthNFCCredentialDerivation.deriveCredentials(uid: sampleUID, masterKey: key)
            results.append(creds.password)
        }
        XCTAssertTrue(results.allSatisfy { $0 == expectedPWD })
    }

    func testInvalidUIDLengthIsRejected() {
        XCTAssertThrowsError(try AuthNFCCredentialDerivation.validatedUID([0x04, 0x01])) { error in
            guard case AuthNFCError.invalidUID = error else {
                return XCTFail("Expected invalidUID")
            }
        }
        XCTAssertThrowsError(
            try AuthNFCCredentialDerivation.deriveCredentials(
                uid: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08],
                masterKey: Array(repeating: 0x01, count: 32)
            )
        )
    }

    func testShortMasterKeyIsRejected() {
        XCTAssertThrowsError(
            try AuthNFCCredentialDerivation.deriveCredentials(
                uid: sampleUID,
                masterKey: Array(repeating: 0xAB, count: 16)
            )
        ) { error in
            XCTAssertEqual(error as? AuthNFCError, .invalidMasterKey)
        }
    }

    func testMissingMasterKeyFailsSafely() {
        let provider = FixedAuthNFCMasterKeyProvider(hex: "")
        XCTAssertThrowsError(try provider.masterKeyBytes()) { error in
            XCTAssertEqual(error as? AuthNFCError, .invalidMasterKey)
        }
    }

    func testUIDParsedFromPage0Read() throws {
        // Page0: 04 DE AD BCC | Page1: BE EF 01 02
        var block = Data(repeating: 0, count: 16)
        block[0] = 0x04
        block[1] = 0xDE
        block[2] = 0xAD
        block[3] = 0x00
        block[4] = 0xBE
        block[5] = 0xEF
        block[6] = 0x01
        block[7] = 0x02
        let uid = try AuthNFCCredentialDerivation.uidBytes(fromPage0Read: block)
        XCTAssertEqual(uid, sampleUID)
    }

    func testTestVectorsMatchDocumentedProtocol() throws {
        let key = try BundleAuthNFCMasterKeyProvider.parseMasterKeyHex(testKeyHex)
        let creds = try AuthNFCCredentialDerivation.deriveCredentials(uid: sampleUID, masterKey: key)
        XCTAssertEqual(creds.passwordHex, "6D4105A4")
        XCTAssertEqual(creds.packHex, "DF86")
        XCTAssertEqual(creds.uidHex, "04DEADBEEF0102")
    }

    func testProviderDisplayHexIsUppercase() throws {
        let provider = FixedAuthNFCMasterKeyProvider(hex: testKeyHex.lowercased())
        XCTAssertEqual(try provider.masterKeyHexForDisplay(), testKeyHex.uppercased())
    }
}
