//
//  NFCLinkDisplayFormatter.swift
//  RAZN NFC
//
//  Display-only labels for stored NFC link URLs. Never mutates the source string.
//

import Foundation

enum NFCLinkDisplayFormatter {
    /// Returns a cleaner viewing label for a raw URL string without changing the value.
    static func displayLabel(for raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        guard let url = URL(string: normalizedForParsing(trimmed)),
              let host = url.host?.lowercased(),
              !host.isEmpty else {
            return trimmed
        }

        let pathSegments = url.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        if matchesHost(host, suffixes: ["instagram.com"]) {
            return brandedHandle(brand: "Instagram", handle: firstMeaningfulSegment(pathSegments))
        }

        if matchesHost(host, suffixes: ["wa.me", "api.whatsapp.com", "whatsapp.com"]) {
            return whatsAppLabel(url: url, pathSegments: pathSegments)
        }

        if matchesHost(host, suffixes: ["tiktok.com", "vm.tiktok.com"]) {
            return tikTokLabel(pathSegments: pathSegments)
        }

        if matchesHost(host, suffixes: ["t.me", "telegram.me"]) {
            return brandedHandle(brand: "Telegram", handle: firstMeaningfulSegment(pathSegments))
        }

        if matchesHost(host, suffixes: ["linkedin.com"]) {
            return linkedInLabel(pathSegments: pathSegments)
        }

        if matchesHost(host, suffixes: ["paypal.me", "paypal.com"]) {
            return payPalLabel(host: host, pathSegments: pathSegments)
        }

        if matchesHost(host, suffixes: ["youtube.com", "youtu.be"]) {
            return youTubeLabel(host: host, pathSegments: pathSegments, queryItems: URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        }

        if matchesHost(host, suffixes: ["x.com", "twitter.com"]) {
            return brandedHandle(brand: "X", handle: firstMeaningfulSegment(pathSegments, skipping: Self.xSkippedSegments))
        }

        if matchesHost(host, suffixes: ["facebook.com", "fb.com", "fb.me"]) {
            return facebookLabel(pathSegments: pathSegments)
        }

        return stripWWW(host)
    }

    // MARK: - Platform helpers

    private static let xSkippedSegments: Set<String> = ["i", "intent", "share", "home", "explore", "search"]
    private static let facebookSkippedSegments: Set<String> = ["profile.php", "people", "pages", "groups", "watch", "reel", "share", "story.php"]
    private static let genericSkippedSegments: Set<String> = ["p", "reel", "reels", "stories", "share", "s", "video", "channel", "c", "user", "u", "@"]

    private static func whatsAppLabel(url: URL, pathSegments: [String]) -> String {
        let phoneDigits: String
        if let phoneQuery = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name.lowercased() == "phone" })?
            .value {
            phoneDigits = phoneQuery.filter(\.isNumber)
        } else {
            phoneDigits = (pathSegments.first ?? "").filter(\.isNumber)
        }

        guard !phoneDigits.isEmpty else {
            return "WhatsApp"
        }

        let suffix = String(phoneDigits.suffix(4))
        return "WhatsApp · ••••\(suffix)"
    }

    private static func tikTokLabel(pathSegments: [String]) -> String {
        guard let first = pathSegments.first, !first.isEmpty else { return "TikTok" }
        if first.hasPrefix("@") {
            return "TikTok · \(first)"
        }
        // Profile paths use @username; opaque short codes (vm.tiktok.com/…) stay unprefixed.
        if first.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." })
            && first.count >= 2
            && first.contains(where: \.isLetter) {
            return "TikTok · @\(first)"
        }
        return "TikTok · \(first)"
    }

    private static func linkedInLabel(pathSegments: [String]) -> String {
        guard let first = pathSegments.first?.lowercased() else {
            return "LinkedIn"
        }
        if first == "in" || first == "company" || first == "school",
           let slug = pathSegments.dropFirst().first {
            return "LinkedIn · \(first)/\(slug)"
        }
        return "LinkedIn · \(pathSegments[0])"
    }

    private static func payPalLabel(host: String, pathSegments: [String]) -> String {
        if host.hasSuffix("paypal.me"), let username = pathSegments.first {
            return "PayPal · \(username)"
        }
        // paypal.com/paypalme/username or /donate/...
        if let paypalmeIndex = pathSegments.firstIndex(where: { $0.lowercased() == "paypalme" }),
           paypalmeIndex + 1 < pathSegments.count {
            return "PayPal · \(pathSegments[paypalmeIndex + 1])"
        }
        if let slug = firstMeaningfulSegment(pathSegments, skipping: ["donate", "cgi-bin", "webapps"]) {
            return "PayPal · \(slug)"
        }
        return "PayPal"
    }

    private static func youTubeLabel(host: String, pathSegments: [String], queryItems: [URLQueryItem]?) -> String {
        if host.hasSuffix("youtu.be"), let id = pathSegments.first {
            return "YouTube · \(id)"
        }
        if let first = pathSegments.first {
            if first.hasPrefix("@") {
                return "YouTube · \(ensureAtPrefix(first))"
            }
            let lower = first.lowercased()
            if lower == "channel" || lower == "c" || lower == "user",
               let slug = pathSegments.dropFirst().first {
                return "YouTube · \(slug)"
            }
            if lower == "watch" {
                if let videoID = queryItems?.first(where: { $0.name == "v" })?.value, !videoID.isEmpty {
                    return "YouTube · \(videoID)"
                }
            }
            if lower == "shorts", let id = pathSegments.dropFirst().first {
                return "YouTube · \(id)"
            }
        }
        if let slug = firstMeaningfulSegment(pathSegments) {
            return "YouTube · \(slug)"
        }
        return "YouTube"
    }

    private static func facebookLabel(pathSegments: [String]) -> String {
        if let slug = firstMeaningfulSegment(pathSegments, skipping: Self.facebookSkippedSegments) {
            return "Facebook · \(slug)"
        }
        return "Facebook"
    }

    private static func brandedHandle(brand: String, handle: String?) -> String {
        guard let handle, !handle.isEmpty else { return brand }
        return "\(brand) · \(ensureAtPrefix(handle))"
    }

    // MARK: - Parsing utilities

    /// Mirrors `NFCViewModel.normalizeURLInput` for parse-only use.
    private static func normalizedForParsing(_ raw: String) -> String {
        let lowercased = raw.lowercased()
        if lowercased.hasPrefix("http://") ||
            lowercased.hasPrefix("https://") ||
            lowercased.hasPrefix("www.") {
            if lowercased.hasPrefix("www.") {
                return "https://\(raw)"
            }
            return raw
        }
        return "https://\(raw)"
    }

    private static func matchesHost(_ host: String, suffixes: [String]) -> Bool {
        suffixes.contains { suffix in
            host == suffix || host.hasSuffix(".\(suffix)")
        }
    }

    private static func stripWWW(_ host: String) -> String {
        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }
        return host
    }

    private static func firstMeaningfulSegment(
        _ pathSegments: [String],
        skipping extra: Set<String> = []
    ) -> String? {
        let skipped = Self.genericSkippedSegments.union(extra)
        return pathSegments.first { segment in
            let lower = segment.lowercased()
            return !skipped.contains(lower)
        }
    }

    private static func ensureAtPrefix(_ handle: String) -> String {
        if handle.hasPrefix("@") { return handle }
        return "@\(handle)"
    }
}
