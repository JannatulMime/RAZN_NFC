//
//  AuthNFCPasswordServiceTests.swift
//  RAZN NFCTests
//
//  Pure validation / encoding / profile tests. Physical NFC behavior is not covered here.
//
//  Manual hardware checklist (not automated; requires physical tags):
//  1. Read unprotected NTAG213 without a password (Read Tag No Authentication)
//  2. Read unprotected NTAG215 without a password
//  3. Read protected tag with readable user memory (PROT=0) and confirm no PWD_AUTH
//  4. Attempt read of genuinely read-protected content (PROT=1) → authentication required
//  5. Write to unprotected tag via Authenticate & Write with empty password (normal write)
//  6. Write to protected tag with correct password → verified success
//  7. Write to protected tag with wrong password → authentication failed, no write
//  8. Protected write without authentication must fail safely
//  9. Read back written payload without authentication when PROT=0
//  10. Regression: production NFC Write/Read on unprotected tags still works unchanged
//

import XCTest
@testable import RAZN_NFC

final class AuthNFCPasswordServiceTests: XCTestCase {

    func testPasswordBytesAcceptsExactEightHex() throws {
        let bytes = try AuthNFCPasswordService.passwordBytes(fromHex: "AABBCCDD")
        XCTAssertEqual(bytes, [0xAA, 0xBB, 0xCC, 0xDD])
    }

    func testPasswordBytesIsCaseInsensitive() throws {
        let bytes = try AuthNFCPasswordService.passwordBytes(fromHex: "aabbccdd")
        XCTAssertEqual(bytes, [0xAA, 0xBB, 0xCC, 0xDD])
    }

    func testPasswordBytesRejectsWrongLength() {
        XCTAssertThrowsError(try AuthNFCPasswordService.passwordBytes(fromHex: "AABBCC")) { error in
            XCTAssertEqual(error as? AuthNFCError, .invalidPasswordFormat)
        }
        XCTAssertThrowsError(try AuthNFCPasswordService.passwordBytes(fromHex: "AABBCCDDEE")) { error in
            XCTAssertEqual(error as? AuthNFCError, .invalidPasswordFormat)
        }
    }

    func testPasswordBytesRejectsNonHex() {
        XCTAssertThrowsError(try AuthNFCPasswordService.passwordBytes(fromHex: "GGHHIIJJ")) { error in
            XCTAssertEqual(error as? AuthNFCError, .invalidPasswordFormat)
        }
    }

    func testPasswordBytesDoesNotPadOrTruncate() {
        // Shorter strings must fail (no silent padding).
        XCTAssertThrowsError(try AuthNFCPasswordService.passwordBytes(fromHex: "AA"))
    }

    func testValidateMatchingPasswords() throws {
        let bytes = try AuthNFCPasswordService.validateMatchingPasswords(
            password: "11223344",
            confirmation: "11223344"
        )
        XCTAssertEqual(bytes, [0x11, 0x22, 0x33, 0x44])
    }

    func testValidateMatchingPasswordsRejectsMismatch() {
        XCTAssertThrowsError(
            try AuthNFCPasswordService.validateMatchingPasswords(
                password: "11223344",
                confirmation: "11223345"
            )
        ) { error in
            XCTAssertEqual(error as? AuthNFCError, .passwordConfirmationMismatch)
        }
    }

    func testDerivedPACKIsDeterministicTwoBytes() throws {
        let pwd = try AuthNFCPasswordService.passwordBytes(fromHex: "01020304")
        let pack1 = AuthNFCPasswordService.derivedPACK(fromPasswordBytes: pwd)
        let pack2 = AuthNFCPasswordService.derivedPACK(fromPasswordBytes: pwd)
        XCTAssertEqual(pack1.count, 2)
        XCTAssertEqual(pack1, pack2)
    }

    func testEncodeDecodeContentRoundTrip() throws {
        let profile = AuthNFCTagProfile.ntag215
        let encoded = try AuthNFCPasswordService.encodeContent("Hello NTAG215", for: profile)
        let decoded = try AuthNFCPasswordService.decodeContent(encoded, for: profile)
        XCTAssertEqual(decoded, "Hello NTAG215")
    }

    func testEncodeRejectsEmptyAndTooLargeForProfile() {
        XCTAssertThrowsError(
            try AuthNFCPasswordService.encodeContent("", for: .ntag215)
        ) { error in
            XCTAssertEqual(error as? AuthNFCError, .emptyContent)
        }
        let huge = String(repeating: "a", count: AuthNFCTagProfile.ntag213.maxContentUTF8ByteCount + 1)
        XCTAssertThrowsError(
            try AuthNFCPasswordService.encodeContent(huge, for: .ntag213)
        ) { error in
            XCTAssertEqual(
                error as? AuthNFCError,
                .contentTooLarge(maxUTF8Bytes: AuthNFCTagProfile.ntag213.maxContentUTF8ByteCount)
            )
        }
    }

    func testMakeCFG1ClearsPROTAndCFGLCKAndAuthLim() {
        let snapshot = AuthNFCConfigSnapshot(
            mirror: 0,
            mirrorPage: 0,
            auth0: 0xFF,
            access: 0xFF,
            cfg0Raw: [0, 0, 0, 0xFF],
            cfg1Raw: [0xFF, 0x11, 0x22, 0x33]
        )
        let page = AuthNFCPasswordService.makeCFG1WriteProtectOnly(preserving: snapshot)
        XCTAssertEqual(page.count, 4)
        XCTAssertEqual(page[0] & AuthNFCConstants.accessBitPROT, 0)
        XCTAssertEqual(page[0] & AuthNFCConstants.accessBitCFGLCK, 0)
        XCTAssertEqual(page[0] & AuthNFCConstants.accessBitAuthLimMask, 0)
    }

    func testMakeCFG0SetsAuth0PreservingMirror() {
        let snapshot = AuthNFCConfigSnapshot(
            mirror: 0x12,
            mirrorPage: 0x34,
            auth0: 0xFF,
            access: 0,
            cfg0Raw: [0x12, 0x00, 0x34, 0xFF],
            cfg1Raw: [0, 0, 0, 0]
        )
        let page = AuthNFCPasswordService.makeCFG0(preserving: snapshot, auth0: 0x04)
        XCTAssertEqual(page[0], 0x12)
        XCTAssertEqual(page[2], 0x34)
        XCTAssertEqual(page[3], 0x04)
    }

    func testMakeCFG0DisableAuth0PreservesUnrelatedBytes() {
        let snapshot = AuthNFCConfigSnapshot(
            mirror: 0xAB,
            mirrorPage: 0xCD,
            auth0: 0x04,
            access: 0,
            cfg0Raw: [0xAB, 0x00, 0xCD, 0x04],
            cfg1Raw: [0x80, 0, 0, 0]
        )
        let page = AuthNFCPasswordService.makeCFG0(
            preserving: snapshot,
            auth0: AuthNFCConstants.auth0Disabled
        )
        XCTAssertEqual(page, [0xAB, 0x00, 0xCD, 0xFF])
        XCTAssertEqual(page[3], AuthNFCConstants.auth0Disabled)
        // ACCESS / CFG1 must not be touched by CFG0 builder.
        XCTAssertEqual(snapshot.cfg1Raw[0], 0x80)
    }

    func testUnregisterVerificationFailedDoesNotExposePassword() {
        let error = AuthNFCError.configurationVerificationFailed
        XCTAssertEqual(error.title, "Verification Failed")
        XCTAssertTrue(error.explanation.contains("could not be verified"))
        XCTAssertFalse(error.explanation.lowercased().contains("a1b2"))
        XCTAssertFalse((error.technicalDetails ?? "").lowercased().contains("password:"))
    }

    func testConfigSnapshotFlags() throws {
        let snap = try AuthNFCConfigSnapshot.parse(
            cfg0: Data([0x00, 0x00, 0x00, 0x04]),
            cfg1: Data([0xC0, 0x00, 0x00, 0x00]) // PROT + CFGLCK
        )
        XCTAssertTrue(snap.isProtectionEnabled)
        XCTAssertTrue(snap.isReadWriteProtection)
        XCTAssertTrue(snap.isConfigLocked)
    }

    func testVersionInfoDetectsNTAGVariants() throws {
        let ntag213 = try AuthNFCVersionInfo.parse(Data([0x00, 0x04, 0x04, 0x02, 0x01, 0x00, 0x0F, 0x03]))
        XCTAssertTrue(ntag213.isNTAG213)
        XCTAssertEqual(ntag213.resolvedProfile?.variant, .ntag213)

        let ntag215 = try AuthNFCVersionInfo.parse(Data([0x00, 0x04, 0x04, 0x02, 0x01, 0x00, 0x11, 0x03]))
        XCTAssertTrue(ntag215.isNTAG215)
        XCTAssertEqual(ntag215.resolvedProfile?.variant, .ntag215)

        let ntag216 = try AuthNFCVersionInfo.parse(Data([0x00, 0x04, 0x04, 0x02, 0x01, 0x00, 0x13, 0x03]))
        XCTAssertTrue(ntag216.isNTAG216)
        XCTAssertEqual(ntag216.resolvedProfile?.variant, .ntag216)
    }

    func testVersionInfoRejectsUnknownStorageAndNonNXP() throws {
        let unknownStorage = try AuthNFCVersionInfo.parse(Data([0x00, 0x04, 0x04, 0x02, 0x01, 0x00, 0x10, 0x03]))
        XCTAssertNil(unknownStorage.resolvedProfile)
        XCTAssertFalse(unknownStorage.isSupportedNTAG21x)

        let nonNXP = try AuthNFCVersionInfo.parse(Data([0x00, 0x05, 0x04, 0x02, 0x01, 0x00, 0x11, 0x03]))
        XCTAssertNil(nonNXP.resolvedProfile)

        let wrongProductType = try AuthNFCVersionInfo.parse(Data([0x00, 0x04, 0x03, 0x02, 0x01, 0x00, 0x11, 0x03]))
        XCTAssertNil(wrongProductType.resolvedProfile)
    }

    func testVersionInfoRequiresEightBytes() {
        XCTAssertThrowsError(try AuthNFCVersionInfo.parse(Data([0x00, 0x04, 0x04, 0x02, 0x01, 0x00, 0x11]))) { error in
            guard case .versionIdentificationFailed = error as? AuthNFCError else {
                return XCTFail("Expected versionIdentificationFailed")
            }
        }
    }

    func testTagProfilesMatchDatasheetAddressesAndBoundaries() {
        let n213 = AuthNFCTagProfile.ntag213
        XCTAssertEqual(n213.cfg0Page, 0x29)
        XCTAssertEqual(n213.cfg1Page, 0x2A)
        XCTAssertEqual(n213.pwdPage, 0x2B)
        XCTAssertEqual(n213.packPage, 0x2C)
        XCTAssertEqual(n213.userMemoryEndPage, 0x27)
        XCTAssertEqual(n213.dynamicLockPage, 0x28)
        XCTAssertEqual(n213.userMemoryByteCount, 144)
        XCTAssertEqual(n213.maxContentUTF8ByteCount, 142)

        let n215 = AuthNFCTagProfile.ntag215
        XCTAssertEqual(n215.cfg0Page, 0x83)
        XCTAssertEqual(n215.cfg1Page, 0x84)
        XCTAssertEqual(n215.pwdPage, 0x85)
        XCTAssertEqual(n215.packPage, 0x86)
        XCTAssertEqual(n215.userMemoryEndPage, 0x81)
        XCTAssertEqual(n215.dynamicLockPage, 0x82)
        XCTAssertEqual(n215.userMemoryByteCount, 504)
        XCTAssertEqual(n215.maxContentUTF8ByteCount, 502)

        let n216 = AuthNFCTagProfile.ntag216
        XCTAssertEqual(n216.cfg0Page, 0xE3)
        XCTAssertEqual(n216.cfg1Page, 0xE4)
        XCTAssertEqual(n216.pwdPage, 0xE5)
        XCTAssertEqual(n216.packPage, 0xE6)
        XCTAssertEqual(n216.userMemoryEndPage, 0xE1)
        XCTAssertEqual(n216.dynamicLockPage, 0xE2)
        XCTAssertEqual(n216.userMemoryByteCount, 888)
        XCTAssertEqual(n216.maxContentUTF8ByteCount, 886)
    }

    func testPageBoundaryHelpersRejectOverflow() throws {
        let profile = AuthNFCTagProfile.ntag213
        let maxFit = String(repeating: "a", count: profile.maxContentUTF8ByteCount)
        let encoded = try AuthNFCPasswordService.encodeContent(maxFit, for: profile)
        XCTAssertTrue(profile.canFitEncodedData(encoded))
        XCTAssertEqual(
            profile.lastContentPage(forEncodedByteCount: encoded.count),
            Int(profile.userMemoryEndPage)
        )

        // One extra UTF-8 byte must fail encode (no silent truncate).
        let tooBig = maxFit + "b"
        XCTAssertThrowsError(try AuthNFCPasswordService.encodeContent(tooBig, for: profile))
    }

    func testContentFittingNTAG215MayExceedNTAG213() throws {
        let text = String(repeating: "x", count: 200)
        XCTAssertNoThrow(try AuthNFCPasswordService.encodeContent(text, for: .ntag215))
        XCTAssertThrowsError(try AuthNFCPasswordService.encodeContent(text, for: .ntag213)) { error in
            XCTAssertEqual(
                error as? AuthNFCError,
                .contentTooLarge(maxUTF8Bytes: AuthNFCTagProfile.ntag213.maxContentUTF8ByteCount)
            )
        }
    }

    func testErrorSurfacesTitleExplanationAndNextStep() {
        let error = AuthNFCError.invalidPasswordFormat
        XCTAssertFalse(error.title.isEmpty)
        XCTAssertFalse(error.explanation.isEmpty)
        XCTAssertFalse(error.suggestedNextStep.isEmpty)
    }

    func testProtectionDisabledWhenAuth0IsFFOrPastPackPage() {
        let profile = AuthNFCTagProfile.ntag213
        XCTAssertFalse(AuthNFCProtection.isEffectivelyEnabled(auth0: 0xFF, profile: profile))
        XCTAssertFalse(AuthNFCProtection.isEffectivelyEnabled(auth0: 0x2D, profile: profile)) // past PACK 0x2C
        XCTAssertTrue(AuthNFCProtection.isEffectivelyEnabled(auth0: 0x04, profile: profile))
        XCTAssertTrue(AuthNFCProtection.isEffectivelyEnabled(auth0: profile.packPage, profile: profile))
    }

    func testWriteRangeRequiresAuthUsesFullPageSpan() {
        let profile = AuthNFCTagProfile.ntag215
        // AUTH0 mid-memory: start page alone is below AUTH0, but a multi-page write crosses it.
        XCTAssertFalse(
            AuthNFCProtection.writeRangeRequiresAuthentication(
                startPage: 0x04,
                pageCount: 1,
                auth0: 0x10,
                profile: profile
            )
        )
        XCTAssertTrue(
            AuthNFCProtection.writeRangeRequiresAuthentication(
                startPage: 0x04,
                pageCount: 16, // pages 0x04...0x13
                auth0: 0x10,
                profile: profile
            )
        )
        XCTAssertTrue(
            AuthNFCProtection.writeRangeRequiresAuthentication(
                startPage: 0x04,
                pageCount: 2,
                auth0: 0x04,
                profile: profile
            )
        )
        XCTAssertFalse(
            AuthNFCProtection.writeRangeRequiresAuthentication(
                startPage: 0x04,
                pageCount: 4,
                auth0: 0xFF,
                profile: profile
            )
        )
    }

    func testInterpretUserMemoryPrefersDemoThenNDEF() throws {
        let profile = AuthNFCTagProfile.ntag213
        let encoded = try AuthNFCPasswordService.encodeContent("demo-text", for: profile)
        let demo = AuthNFCPasswordService.interpretUserMemory(encoded, for: profile)
        XCTAssertEqual(demo.format, .demoLengthPrefixed)
        XCTAssertEqual(demo.text, "demo-text")

        // Minimal Type 2 NDEF: NDEF TLV + short Text record "Hi" (en)
        // Record: D1 01 05 54 02 65 6E 48 69  (MB/ME/SR, TNF=1, type T, "en"+"Hi")
        var user = Data([0x03, 0x09, 0xD1, 0x01, 0x05, 0x54, 0x02, 0x65, 0x6E, 0x48, 0x69, 0xFE])
        while user.count < 16 { user.append(0) }
        let ndef = AuthNFCPasswordService.interpretUserMemory(user, for: profile)
        XCTAssertEqual(ndef.format, .ndef)
        XCTAssertEqual(ndef.text, "Hi")

        let empty = AuthNFCPasswordService.interpretUserMemory(Data(repeating: 0, count: 32), for: profile)
        XCTAssertEqual(empty.format, .empty)
    }

    func testConfigSnapshotEffectiveProtectionHonorsProfile() throws {
        let snap = try AuthNFCConfigSnapshot.parse(
            cfg0: Data([0x00, 0x00, 0x00, 0x04]),
            cfg1: Data([0x00, 0x00, 0x00, 0x00])
        )
        XCTAssertTrue(snap.isEffectivelyProtected(on: .ntag213))
        XCTAssertTrue(snap.writeRangeRequiresAuthentication(startPage: 0x04, pageCount: 2, profile: .ntag213))
        XCTAssertFalse(snap.readRequiresAuthentication(forPage: 0x04, profile: .ntag213)) // PROT=0

        let readProt = try AuthNFCConfigSnapshot.parse(
            cfg0: Data([0x00, 0x00, 0x00, 0x04]),
            cfg1: Data([0x80, 0x00, 0x00, 0x00])
        )
        XCTAssertTrue(readProt.readRequiresAuthentication(forPage: 0x04, profile: .ntag215))
    }
}
