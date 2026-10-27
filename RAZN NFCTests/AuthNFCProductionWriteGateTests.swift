//
//  AuthNFCProductionWriteGateTests.swift
//  RAZN NFCTests
//
//  Production write policy. No NFC hardware. A scripted tag records READ / PWD_AUTH / WRITE.
//
//  Still needs a physical tag:
//  1. Unprotected NTAG213 and NTAG215 show "Unprotected Tag" and do not write.
//  2. NTAG213/215 with AUTH0 at or before page 04h and the Tag Manager password writes.
//  3. The same tag with a different password shows "Wrong Tag" and does not write.
//  4. PROT=1 tags whose CFG pages NAK before PWD_AUTH are rejected as unreadable, not written.
//  5. Production Read still completes with no password.
//

import CoreNFC
import XCTest
@testable import RAZN_NFC

final class AuthNFCProductionWriteGateTests: XCTestCase {

    private let passwordHex = AuthNFCConstants.tagManagerPasswordHex

    func testUnprotectedNTAG213IsRejectedWithNoWrite() async throws {
        let tag = makeTag(profile: .ntag213, auth0: 0xFF, access: 0x00)
        try await expectRejection(tag, .unprotectedTag)
        XCTAssertFalse(tag.didAuthenticate)
        XCTAssertTrue(tag.commands.contains(Data([AuthNFCConstants.cmdRead, AuthNFCTagProfile.ntag213.cfg0Page])))
        let alert = try XCTUnwrap(AuthNFCProductionWriteAlert.presented(for: AuthNFCError.unprotectedTag))
        XCTAssertEqual(alert.title, "Unprotected Tag")
        XCTAssertEqual(
            alert.message,
            "This tag does not have password protection enabled. Writing is not allowed."
        )
    }

    func testUnprotectedNTAG215IsRejectedWithNoWrite() async throws {
        let tag = makeTag(profile: .ntag215, auth0: 0xFF, access: 0x80)
        try await expectRejection(tag, .unprotectedTag)
        XCTAssertFalse(tag.didAuthenticate)
        XCTAssertTrue(tag.commands.contains(Data([AuthNFCConstants.cmdRead, AuthNFCTagProfile.ntag215.cfg0Page])))
        XCTAssertFalse(tag.commands.contains(Data([AuthNFCConstants.cmdRead, AuthNFCTagProfile.ntag213.cfg0Page])))
    }

    func testAuth0PastPackPageIsUnprotectedOn213And215() {
        XCTAssertFalse(
            AuthNFCProtection.productionDestinationIsFullyProtected(
                startPage: 0x04,
                pageCount: 4,
                auth0: 0x2D,
                access: 0x00,
                profile: .ntag213
            )
        )
        XCTAssertFalse(
            AuthNFCProtection.productionDestinationIsFullyProtected(
                startPage: 0x04,
                pageCount: 4,
                auth0: 0x87,
                access: 0x80,
                profile: .ntag215
            )
        )
        XCTAssertTrue(
            AuthNFCProtection.productionDestinationIsFullyProtected(
                startPage: 0x04,
                pageCount: 8,
                auth0: 0x04,
                access: 0x00,
                profile: .ntag213
            )
        )
        XCTAssertTrue(
            AuthNFCProtection.productionDestinationIsFullyProtected(
                startPage: 0x04,
                pageCount: 8,
                auth0: 0x04,
                access: 0x80,
                profile: .ntag215
            )
        )
        XCTAssertFalse(
            AuthNFCProtection.productionDestinationIsFullyProtected(
                startPage: 0x04,
                pageCount: 2,
                auth0: 0x05,
                access: 0x00,
                profile: .ntag213
            )
        )
    }

    func testProtectedTagWithCorrectPasswordAuthenticatesThenWrites() async throws {
        let password = try AuthNFCPasswordService.passwordBytes(fromHex: passwordHex)
        let profile = AuthNFCTagProfile.ntag213
        let tag = makeTag(profile: profile, auth0: 0x04, access: 0x00, acceptedPassword: password)

        let prep = try await AuthNFCProductionWriteGate.prepareAuthenticatedWrite(
            tag: tag,
            ndefMessage: sampleMessage()
        )
        XCTAssertTrue(prep.authenticated)
        XCTAssertEqual(prep.profile, profile)
        XCTAssertTrue(tag.didAuthenticate)
        XCTAssertTrue(tag.writeCommands.isEmpty)

        try await AuthNFCProductionWriteGate.writeNDEFViaPages(
            tag: tag,
            message: sampleMessage(),
            profile: profile,
            authenticated: true
        )
        assertWritesFollowAuthentication(on: tag, profile: profile)
    }

    func testProtectedNTAG215WithReadAndWriteProtStillRequiresAuthBeforeWrite() async throws {
        let password = try AuthNFCPasswordService.passwordBytes(fromHex: passwordHex)
        let profile = AuthNFCTagProfile.ntag215
        let tag = makeTag(profile: profile, auth0: 0x04, access: 0x80, acceptedPassword: password)
        try await AuthNFCProductionWriteGate.writeProtectedNDEF(
            tag: tag,
            message: sampleMessage()
        )
        assertWritesFollowAuthentication(on: tag, profile: profile)
        XCTAssertTrue(tag.commands.contains(Data([AuthNFCConstants.cmdRead, profile.cfg0Page])))
    }

    func testProtectedTagWithWrongPasswordDoesNotWrite() async throws {
        let tag = makeTag(
            profile: .ntag215,
            auth0: 0x04,
            access: 0x00,
            acceptedPassword: [0xFF, 0xFF, 0xFF, 0xFF]
        )
        try await expectRejection(tag, .authenticationRejected)
        XCTAssertTrue(tag.didAuthenticate)
        let alert = try XCTUnwrap(AuthNFCProductionWriteAlert.presented(for: AuthNFCError.authenticationRejected))
        XCTAssertEqual(alert.title, "Wrong Tag")
        XCTAssertEqual(
            alert.message,
            "Authentication failed. This tag does not match the password configured in this app. Writing is not allowed."
        )
    }

    func testPackMismatchIsWrongTagAndDoesNotWrite() async throws {
        let password = try AuthNFCPasswordService.passwordBytes(fromHex: passwordHex)
        let derived = AuthNFCPasswordService.derivedPACK(fromPasswordBytes: password)
        let wrongPACK: [UInt8] = derived == [0x00, 0x00] ? [0xFF, 0xFF] : [0x00, 0x00]
        let tag = makeTag(
            profile: .ntag213,
            auth0: 0x00,
            access: 0x00,
            acceptedPassword: password,
            packResponse: wrongPACK
        )
        try await expectRejection(tag, .packMismatch)
        XCTAssertEqual(AuthNFCProductionWriteAlert.presented(for: AuthNFCError.packMismatch)?.title, "Wrong Tag")
    }

    func testUnprotectedTagIsRejectedBeforePasswordIsConsulted() async throws {
        let tag = makeTag(profile: .ntag213, auth0: 0xFF)
        try await expectRejection(tag, .unprotectedTag)
        XCTAssertFalse(tag.didAuthenticate)
    }

    func testDestinationNotFullyCoveredByAuth0IsRejected() async throws {
        let tag = makeTag(profile: .ntag215, auth0: 0x20, access: 0x00)
        try await expectRejection(tag, .unprotectedTag)
        XCTAssertFalse(tag.didAuthenticate)
    }

    func testUnsupportedMiFareFamilyDoesNotWrite() async {
        let tag = makeTag(profile: .ntag213, auth0: 0x04, family: .plus)
        do {
            try await AuthNFCProductionWriteGate.writeProtectedNDEF(
                tag: tag,
                message: sampleMessage()
            )
            XCTFail("Expected unsupported tag")
        } catch let error as AuthNFCError {
            guard case .unsupportedTagType = error else {
                return XCTFail("Expected unsupportedTagType, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error \(error)")
        }
        XCTAssertTrue(tag.writeCommands.isEmpty)
        XCTAssertFalse(tag.didAuthenticate)
        XCTAssertEqual(
            AuthNFCProductionWriteAlert.presented(for: AuthNFCError.unsupportedTagType(details: ""))?.title,
            "Unsupported Tag"
        )
    }

    func testNTAG216AndUnknownStorageAreRejected() async throws {
        let ntag216 = makeTag(profile: .ntag216, auth0: 0x04, storageSize: AuthNFCConstants.ntag216StorageSize)
        do {
            try await AuthNFCProductionWriteGate.writeProtectedNDEF(
                tag: ntag216,
                message: sampleMessage()
            )
            XCTFail("Expected NTAG216 rejection")
        } catch let error as AuthNFCError {
            guard case .unsupportedTagType = error else {
                return XCTFail("Expected unsupportedTagType, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error \(error)")
        }
        XCTAssertTrue(ntag216.writeCommands.isEmpty)
        XCTAssertFalse(ntag216.didAuthenticate)

        let unknown = makeTag(profile: .ntag213, auth0: 0x04, storageSize: 0x10)
        do {
            try await AuthNFCProductionWriteGate.writeProtectedNDEF(
                tag: unknown,
                message: sampleMessage()
            )
            XCTFail("Expected unknown storage rejection")
        } catch let error as AuthNFCError {
            guard case .unsupportedTagType = error else {
                return XCTFail("Expected unsupportedTagType, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error \(error)")
        }
        XCTAssertTrue(unknown.writeCommands.isEmpty)
    }

    func testConfigurationReadFailureIsNotTreatedAsUnprotected() async throws {
        let tag = makeTag(
            profile: .ntag213,
            auth0: 0xFF,
            configReadError: AuthNFCError.unexpectedResponse(details: "NAK")
        )
        try await expectRejection(tag, .configurationUnreadable)
        XCTAssertFalse(tag.didAuthenticate)
        let alert = try XCTUnwrap(AuthNFCProductionWriteAlert.presented(for: AuthNFCError.configurationUnreadable))
        XCTAssertEqual(alert.title, "Configuration Unreadable")
        XCTAssertNotEqual(alert.title, "Unprotected Tag")
        XCTAssertNotEqual(alert.title, "Wrong Tag")
        XCTAssertFalse(alert.message.contains(passwordHex))
    }

    func testTagRemovalDuringConfigReadIsNotWrongTag() async throws {
        let tag = makeTag(
            profile: .ntag215,
            auth0: 0x04,
            configReadError: AuthNFCError.tagRemoved
        )
        try await expectRejection(tag, .tagRemoved)
        XCTAssertFalse(tag.didAuthenticate)
        let alert = try XCTUnwrap(AuthNFCProductionWriteAlert.presented(for: AuthNFCError.tagRemoved))
        XCTAssertEqual(alert.title, "NFC Communication Failed")
        XCTAssertNotEqual(alert.title, "Wrong Tag")
        XCTAssertNotEqual(alert.title, "Unprotected Tag")
    }

    func testUnauthenticatedPageWriteSendsNoCommands() async {
        let tag = makeTag(profile: .ntag213, auth0: 0x04)
        do {
            try await AuthNFCProductionWriteGate.writeNDEFViaPages(
                tag: tag,
                message: sampleMessage(),
                profile: .ntag213,
                authenticated: false
            )
            XCTFail("Expected authenticationRequired")
        } catch AuthNFCError.authenticationRequired {
            XCTAssertTrue(tag.commands.isEmpty)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testProductionAlertsDoNotContainThePassword() throws {
        let samples: [AuthNFCError] = [
            .unprotectedTag,
            .authenticationRejected,
            .packMismatch,
            .noStoredPassword,
            .invalidPasswordFormat,
            .configurationUnreadable,
            .unsupportedTagType(details: "storage"),
            .tagRemoved
        ]
        for error in samples {
            let alert = try XCTUnwrap(AuthNFCProductionWriteAlert.presented(for: error))
            XCTAssertFalse(alert.title.contains(passwordHex))
            XCTAssertFalse(alert.message.contains(passwordHex))
            XCTAssertFalse(alert.message.lowercased().contains("pwd:"))
        }
        XCTAssertNil(AuthNFCProductionWriteAlert.presented(for: AuthNFCError.userCancelled))
    }

    func testDemoUnprotectedWriteRuleIsUnchanged() {
        // The TestNFCAuth demo still treats AUTH0=0xFF as "do not send PWD_AUTH".
        // Production writes use productionDestinationIsFullyProtected and reject that tag.
        XCTAssertFalse(
            AuthNFCProtection.writeRangeRequiresAuthentication(
                startPage: 0x04,
                pageCount: 4,
                auth0: AuthNFCConstants.auth0Disabled,
                profile: .ntag215
            )
        )
    }

    // MARK: - Helpers

    private func expectRejection(
        _ tag: ScriptedAuthNFCTag,
        _ expected: AuthNFCError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        do {
            try await AuthNFCProductionWriteGate.writeProtectedNDEF(
                tag: tag,
                message: sampleMessage()
            )
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch let error as AuthNFCError {
            XCTAssertEqual(error, expected, file: file, line: line)
        }
        XCTAssertTrue(tag.writeCommands.isEmpty, "WRITE was sent", file: file, line: line)
    }

    private func assertWritesFollowAuthentication(
        on tag: ScriptedAuthNFCTag,
        profile: AuthNFCTagProfile,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let authIndex = tag.commands.firstIndex { $0.first == AuthNFCConstants.cmdPwdAuth }
        let writeIndex = tag.commands.firstIndex { $0.first == AuthNFCConstants.cmdWrite }
        XCTAssertNotNil(authIndex, file: file, line: line)
        XCTAssertNotNil(writeIndex, file: file, line: line)
        if let authIndex, let writeIndex {
            XCTAssertLessThan(authIndex, writeIndex, file: file, line: line)
        }
        let forbidden: Set<UInt8> = [
            profile.cfg0Page,
            profile.cfg1Page,
            profile.pwdPage,
            profile.packPage,
            profile.dynamicLockPage
        ]
        for command in tag.writeCommands {
            XCTAssertGreaterThanOrEqual(command.count, 2, file: file, line: line)
            XCTAssertFalse(forbidden.contains(command[1]), "Wrote configuration page \(command[1])", file: file, line: line)
            XCTAssertGreaterThanOrEqual(command[1], profile.userMemoryStartPage, file: file, line: line)
            XCTAssertLessThanOrEqual(command[1], profile.userMemoryEndPage, file: file, line: line)
        }
    }

    private func sampleMessage() -> NFCNDEFMessage {
        let url = URL(string: "https://razn.it/test")!
        let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url)!
        return NFCNDEFMessage(records: [payload])
    }

    private func makeTag(
        profile: AuthNFCTagProfile,
        auth0: UInt8,
        access: UInt8 = 0x00,
        acceptedPassword: [UInt8]? = nil,
        packResponse: [UInt8]? = nil,
        configReadError: Error? = nil,
        family: NFCMiFareFamily = .ultralight,
        storageSize: UInt8? = nil
    ) -> ScriptedAuthNFCTag {
        let storage = storageSize ?? profile.storageSizeByte
        return ScriptedAuthNFCTag(mifareFamily: family) { command in
            guard let op = command.first else {
                throw AuthNFCError.unexpectedResponse(details: "empty command")
            }
            switch op {
            case AuthNFCConstants.cmdGetVersion:
                return Data([0x00, 0x04, 0x04, 0x02, 0x01, 0x00, storage, 0x03])
            case AuthNFCConstants.cmdRead:
                guard command.count >= 2 else {
                    throw AuthNFCError.unexpectedResponse(details: "short READ")
                }
                let page = command[1]
                if page == profile.cfg0Page {
                    if let configReadError {
                        throw configReadError
                    }
                    var block = Data(repeating: 0, count: 16)
                    block[3] = auth0
                    block[4] = access
                    return block
                }
                if page == 0x03 {
                    var cc = Data(repeating: 0, count: 16)
                    cc[0] = 0xE1
                    cc[1] = 0x10
                    switch profile.variant {
                    case .ntag213: cc[2] = 0x12
                    case .ntag215: cc[2] = 0x3F
                    case .ntag216: cc[2] = 0x6D
                    }
                    return cc
                }
                return Data(repeating: 0, count: 16)
            case AuthNFCConstants.cmdPwdAuth:
                let supplied = [UInt8](command.dropFirst())
                guard let acceptedPassword, supplied == acceptedPassword else {
                    throw AuthNFCError.unexpectedResponse(details: "NAK")
                }
                if let packResponse {
                    return Data(packResponse)
                }
                return Data(AuthNFCPasswordService.derivedPACK(fromPasswordBytes: acceptedPassword))
            case AuthNFCConstants.cmdWrite:
                return Data([0x0A])
            default:
                throw AuthNFCError.unexpectedResponse(details: "unexpected command")
            }
        }
    }
}

private final class ScriptedAuthNFCTag: AuthNFCTagCommanding {
    var mifareFamily: NFCMiFareFamily
    private(set) var commands: [Data] = []
    private let responder: (Data) throws -> Data

    init(mifareFamily: NFCMiFareFamily, responder: @escaping (Data) throws -> Data) {
        self.mifareFamily = mifareFamily
        self.responder = responder
    }

    func sendAuthNFCCommand(_ packet: Data) async throws -> Data {
        commands.append(packet)
        return try responder(packet)
    }

    var writeCommands: [Data] {
        commands.filter { $0.first == AuthNFCConstants.cmdWrite }
    }

    var didAuthenticate: Bool {
        commands.contains { $0.first == AuthNFCConstants.cmdPwdAuth }
    }
}
