//
//  NFCLinkDisplayFormatterTests.swift
//  RAZN NFCTests
//

import XCTest
@testable import RAZN_NFC

final class NFCLinkDisplayFormatterTests: XCTestCase {

    // MARK: - Social platforms

    func testInstagramUsesShortBrandAndFitsBudget() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://www.instagram.com/razn.official/"),
            "IG • @razn.official"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "instagram.com/cool_user"),
            "IG • @cool_user"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://www.instagram.com/razvanchiricia"),
            "IG • @razvanchiricia"
        )
        assertWithinLimit(NFCLinkDisplayFormatter.displayLabel(for: "https://www.instagram.com/razvanchiricia"))
    }

    func testWhatsAppMasksPhoneKeepingLastFour() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://wa.me/15551234567"),
            "WhatsApp • ••••4567"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://api.whatsapp.com/send?phone=491761234567"),
            "WhatsApp • ••••4567"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://wa.me/393331230704"),
            "WhatsApp • ••••0704"
        )
    }

    func testTikTokUsername() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://www.tiktok.com/@creator"),
            "TikTok • @creator"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://www.tiktok.com/creator"),
            "TikTok • @creator"
        )
    }

    func testTelegramUsernameFitsOrMiddleTruncates() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://t.me/razn_support"),
            "Telegram • @razn_support"
        )
        // "Telegram • @razvanchiricia" is 26 chars → middle-truncate handle to 14
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://t.me/razvanchiricia"),
            "Telegram • @razvan…iricia"
        )
        assertWithinLimit(NFCLinkDisplayFormatter.displayLabel(for: "https://t.me/razvanchiricia"))
    }

    func testLinkedInReadableName() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://www.linkedin.com/in/jane-doe"),
            "LinkedIn • Jane Doe"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://www.linkedin.com/company/razn"),
            "LinkedIn • Razn"
        )
        // "LinkedIn • Razvan Chiricia" is 27 chars → middle-truncate name to 14
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://www.linkedin.com/in/razvan-chiricia"),
            "LinkedIn • Razvan …iricia"
        )
        assertWithinLimit(
            NFCLinkDisplayFormatter.displayLabel(for: "https://www.linkedin.com/in/razvan-chiricia")
        )
    }

    func testPayPalUsername() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://paypal.me/razn"),
            "PayPal • razn"
        )
    }

    func testYouTubeHandleAndWatch() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://www.youtube.com/@raznchannel"),
            "YouTube • @raznchannel"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
            "YouTube • dQw4w9WgXcQ"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://youtu.be/dQw4w9WgXcQ"),
            "YouTube • dQw4w9WgXcQ"
        )
    }

    func testXTwitterUsername() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://x.com/razn_app"),
            "X • @razn_app"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://twitter.com/razn_app"),
            "X • @razn_app"
        )
    }

    func testFacebookPage() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://www.facebook.com/razn.page"),
            "Facebook • razn.page"
        )
    }

    func testAppStoreReview() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(
                for: "https://apps.apple.com/app/id6749680572?action=write-review"
            ),
            "App Store • Review"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(
                for: "https://apps.apple.com/us/app/razn/id6749680572"
            ),
            "App Store • Razn"
        )
    }

    // MARK: - Websites (path-aware)

    func testRaznItPagesAreDistinguishable() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://razn.it/pages/start"),
            "razn.it • Start"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://razn.it/pages/il-centimetro-rosso-di-vlad"),
            "razn.it • Il Cent…Di Vlad"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://razn.it"),
            "razn.it"
        )
        assertWithinLimit(
            NFCLinkDisplayFormatter.displayLabel(for: "https://razn.it/pages/il-centimetro-rosso-di-vlad")
        )
    }

    func testGenericDomainWithPath() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://www.example.com/path?q=1"),
            "example.com • Path"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.displayLabel(for: "https://docs.apple.com/ios"),
            "docs.apple.com • Ios"
        )
    }

    // MARK: - Budget helpers

    func testComposeNeverExceeds25Characters() {
        let label = NFCLinkDisplayFormatter.compose(
            platform: "Telegram",
            identifier: "@very_long_username_here"
        )
        XCTAssertEqual(label.count, 25)
        XCTAssertTrue(label.hasPrefix("Telegram • "))
        XCTAssertTrue(label.contains("…"))
    }

    func testMiddleEllipsisKeepsStartAndEnd() {
        XCTAssertEqual(
            NFCLinkDisplayFormatter.truncateMiddle("@razvanchiricia", maxLength: 14),
            "@razvan…iricia"
        )
        XCTAssertEqual(
            NFCLinkDisplayFormatter.truncateMiddle("Il Centimetro Rosso Di Vlad", maxLength: 15),
            "Il Cent…Di Vlad"
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

    // MARK: - Helpers

    private func assertWithinLimit(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertLessThanOrEqual(label.count, 25, "Label exceeded 25 chars: \(label)", file: file, line: line)
    }
}
