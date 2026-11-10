//
//  NFCLinkDisplayFormatterTests.swift
//  RAZN NFCTests
//

import XCTest
@testable import RAZN_NFC

final class NFCLinkDisplayFormatterTests: XCTestCase {

    func testInstagramUsername() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://www.instagram.com/razn.official/"),
            "Instagram · @razn.official"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "instagram.com/cool_user"),
            "Instagram · @cool_user"
        )
    }

    func testWhatsAppMasksPhoneKeepingLastFour() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://wa.me/15551234567"),
            "WhatsApp · ••••4567"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://api.whatsapp.com/send?phone=491761234567"),
            "WhatsApp · ••••4567"
        )
    }

    func testTikTokUsername() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://www.tiktok.com/@creator"),
            "TikTok · @creator"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://www.tiktok.com/creator"),
            "TikTok · @creator"
        )
    }

    func testTelegramUsername() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://t.me/razn_support"),
            "Telegram · @razn_support"
        )
    }

    func testLinkedInProfile() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://www.linkedin.com/in/jane-doe"),
            "LinkedIn · in/jane-doe"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://www.linkedin.com/company/razn"),
            "LinkedIn · company/razn"
        )
    }

    func testPayPalUsername() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://paypal.me/razn"),
            "PayPal · razn"
        )
    }

    func testYouTubeHandleAndWatch() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://www.youtube.com/@raznchannel"),
            "YouTube · @raznchannel"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
            "YouTube · dQw4w9WgXcQ"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://youtu.be/dQw4w9WgXcQ"),
            "YouTube · dQw4w9WgXcQ"
        )
    }

    func testXTwitterUsername() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://x.com/razn_app"),
            "X · @razn_app"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://twitter.com/razn_app"),
            "X · @razn_app"
        )
    }

    func testFacebookPage() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://www.facebook.com/razn.page"),
            "Facebook · razn.page"
        )
    }

    func testGenericDomainStripsWWW() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://www.example.com/path?q=1"),
            "example.com"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://docs.apple.com/ios"),
            "docs.apple.com"
        )
    }

    func testEmptyAndUnparseableReturnOriginal() {
        XCTAssertEqual(NFCLinkDisplayFormatter.displayLabel(for: ""), "")
        XCTAssertEqual(NFCLinkDisplayFormatter.displayLabel(for: "   "), "")
        XCTAssertEqual(NFCLinkDisplayFormatter.displayLabel(for: "not a url"), "not a url")
    }

    func testFormatterDoesNotMutateSource() {
        var source = "https://www.instagram.com/razn/"
        let before = source
        _ = NFCLinkDisplayFormatter.displayLabel(for: source)
        XCTAssertEqual(source, before)
        XCTAssertEqual(source, "https://www.instagram.com/razn/")
    }
}
