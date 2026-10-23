//
//  AuthNFCPasswordStoreTests.swift
//  RAZN NFCTests
//
//  Unit tests for local password persistence and production write-gate helpers.
//  Physical NFC / PWD_AUTH hardware behavior is not covered here.
//

import CoreNFC
import XCTest
@testable import RAZN_NFC

final class AuthNFCPasswordStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var store: AuthNFCPasswordStore!
    private let suiteName = "AuthNFCPasswordStoreTests.\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = AuthNFCPasswordStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        super.tearDown()
    }

    func testSaveValidPassword() throws {
        try store.save(hexPassword: "a1b2c3d4")
        XCTAssertEqual(store.retrieve(), "A1B2C3D4")
        XCTAssertTrue(store.hasPassword)
    }

    func testRejectInvalidHexInput() {
        XCTAssertThrowsError(try store.save(hexPassword: "PASS1234")) { error in
            XCTAssertEqual(error as? AuthNFCError, .invalidPasswordFormat)
        }
        XCTAssertThrowsError(try store.save(hexPassword: "ABC123"))
        XCTAssertThrowsError(try store.save(hexPassword: "A1B2C3D4EF"))
        XCTAssertFalse(store.hasPassword)
        XCTAssertNil(defaults.string(forKey: AuthNFCPasswordStore.defaultsKey))
    }

    func testRetrieveStoredPassword() throws {
        try store.save(hexPassword: "12345678")
        XCTAssertEqual(store.retrieve(), "12345678")
    }

    func testClearStoredPassword() throws {
        try store.save(hexPassword: "AABBCCDD")
        store.clear()
        XCTAssertNil(store.retrieve())
        XCTAssertFalse(store.hasPassword)
    }

    func testRetrieveIgnoresMalformedDefaultsValue() {
        defaults.set("not-hex!!", forKey: AuthNFCPasswordStore.defaultsKey)
        XCTAssertNil(store.retrieve())
        XCTAssertFalse(store.hasPassword)
        XCTAssertEqual(store.lookup(), .invalid)
    }

    func testLookupDistinguishesMissingInvalidAndValid() throws {
        XCTAssertEqual(store.lookup(), .missing)
        defaults.set("   ", forKey: AuthNFCPasswordStore.defaultsKey)
        XCTAssertEqual(store.lookup(), .missing)
        defaults.set("abcd", forKey: AuthNFCPasswordStore.defaultsKey)
        XCTAssertEqual(store.lookup(), .invalid)
        try store.save(hexPassword: "a1b2c3d4")
        XCTAssertEqual(store.lookup(), .valid(hex: "A1B2C3D4"))
    }

    func testNoPasswordStoredErrorMessageIsActionable() {
        let error = AuthNFCError.noStoredPassword
        XCTAssertTrue(error.explanation.contains("Store NFC Password"))
        XCTAssertFalse(error.explanation.lowercased().contains("a1b2"))
    }

    func testAuthenticationFailedMessageDoesNotExposePassword() {
        let message = AuthNFCError.authenticationRejected.explanation
        XCTAssertTrue(message.contains("No new payload was written"))
        XCTAssertFalse(message.contains("PWD"))
    }

    func testEstimatedNDEFPageCountIsAtLeastOne() {
        // Empty message still estimates at least one page of TLV/user area.
        let empty = NFCNDEFMessage(records: [])
        XCTAssertGreaterThanOrEqual(AuthNFCProductionWriteGate.estimatedNDEFPageCount(for: empty), 1)

        let url = URL(string: "https://razn.it/test")!
        let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url)!
        let message = NFCNDEFMessage(records: [payload])
        let pages = AuthNFCProductionWriteGate.estimatedNDEFPageCount(for: message)
        XCTAssertGreaterThanOrEqual(pages, 1)
        XCTAssertLessThan(pages, 200)
    }

    func testWriteRangePolicyUnprotectedDoesNotRequireAuth() {
        let profile = AuthNFCTagProfile.ntag215
        XCTAssertFalse(
            AuthNFCProtection.writeRangeRequiresAuthentication(
                startPage: profile.userMemoryStartPage,
                pageCount: 8,
                auth0: 0xFF,
                profile: profile
            )
        )
    }

    func testWriteRangePolicyProtectedRequiresAuth() {
        let profile = AuthNFCTagProfile.ntag213
        XCTAssertTrue(
            AuthNFCProtection.writeRangeRequiresAuthentication(
                startPage: profile.userMemoryStartPage,
                pageCount: 4,
                auth0: profile.userMemoryStartPage,
                profile: profile
            )
        )
    }

    func testNTAG213And215ProfilesRemainDistinct() {
        XCTAssertNotEqual(AuthNFCTagProfile.ntag213.cfg0Page, AuthNFCTagProfile.ntag215.cfg0Page)
        XCTAssertNotEqual(AuthNFCTagProfile.ntag213.pwdPage, AuthNFCTagProfile.ntag215.pwdPage)
        XCTAssertEqual(AuthNFCTagProfile.ntag213.cfg0Page, 0x29)
        XCTAssertEqual(AuthNFCTagProfile.ntag215.cfg0Page, 0x83)
        XCTAssertEqual(AuthNFCTagProfile.profile(forStorageSize: 0x0F)?.variant, .ntag213)
        XCTAssertEqual(AuthNFCTagProfile.profile(forStorageSize: 0x11)?.variant, .ntag215)
        XCTAssertNil(AuthNFCTagProfile.profile(forStorageSize: 0x10))
    }

    func testAuth0DisabledDisablesEffectiveProtectionOn213And215() {
        XCTAssertFalse(
            AuthNFCProtection.isEffectivelyEnabled(
                auth0: AuthNFCConstants.auth0Disabled,
                profile: .ntag213
            )
        )
        XCTAssertFalse(
            AuthNFCProtection.isEffectivelyEnabled(
                auth0: AuthNFCConstants.auth0Disabled,
                profile: .ntag215
            )
        )
        XCTAssertTrue(
            AuthNFCProtection.isEffectivelyEnabled(
                auth0: AuthNFCTagProfile.ntag213.userMemoryStartPage,
                profile: .ntag213
            )
        )
        XCTAssertTrue(
            AuthNFCProtection.isEffectivelyEnabled(
                auth0: AuthNFCTagProfile.ntag215.userMemoryStartPage,
                profile: .ntag215
            )
        )
    }

    func testType2NDEFEncodingProducesReadableURITLV() throws {
        let url = URL(string: "https://razn.it/test")!
        let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url)!
        let message = NFCNDEFMessage(records: [payload])
        let tlv = try AuthNFCProductionWriteGate.type2UserMemory(for: message, profile: .ntag215)

        XCTAssertEqual(tlv.first, 0x03) // NDEF TLV
        XCTAssertEqual(tlv.last { $0 != 0 }, 0xFE) // terminator before padding zeros

        let ndef = AuthNFCProductionWriteGate.serializeNDEFMessage(message)
        XCTAssertFalse(ndef.isEmpty)
        // Well-known URI record type is "U"
        XCTAssertTrue(ndef.contains(UInt8(ascii: "U")))
    }
}
