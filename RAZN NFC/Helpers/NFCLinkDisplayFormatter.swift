//
//  NFCLinkDisplayFormatter.swift
//  RAZN NFC
//
//  Display-only labels for stored NFC link URLs. Never mutates the source string.
//  Hard limit: 25 characters total. Format: Platform • identifier
//  When over budget, keep the platform/domain and middle-truncate the identifier.
//

import Foundation

enum NFCLinkDisplayFormatter {
    private static let maxLength = 25
    private static let separator = " • "

    /// Returns a cleaner viewing label for a raw URL string without changing the value.
    static func displayLabel(for raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        guard let url = URL(string: normalizedForParsing(trimmed)),
              let host = url.host?.lowercased(),
              !host.isEmpty else {
            return truncateMiddle(trimmed, maxLength: maxLength)
        }

        let pathSegments = url.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        if matchesHost(host, suffixes: ["instagram.com"]) {
            return compose(platform: "IG", identifier: atHandle(firstMeaningfulSegment(pathSegments)))
        }

        if matchesHost(host, suffixes: ["wa.me", "api.whatsapp.com", "whatsapp.com"]) {
            return whatsAppLabel(url: url, pathSegments: pathSegments)
        }

        if matchesHost(host, suffixes: ["tiktok.com", "vm.tiktok.com"]) {
            return compose(platform: "TikTok", identifier: tikTokIdentifier(pathSegments: pathSegments))
        }

        if matchesHost(host, suffixes: ["t.me", "telegram.me"]) {
            return compose(platform: "Telegram", identifier: atHandle(firstMeaningfulSegment(pathSegments)))
        }

        if matchesHost(host, suffixes: ["linkedin.com"]) {
            return compose(platform: "LinkedIn", identifier: linkedInIdentifier(pathSegments: pathSegments))
        }

        if matchesHost(host, suffixes: ["paypal.me", "paypal.com"]) {
            return compose(platform: "PayPal", identifier: payPalIdentifier(host: host, pathSegments: pathSegments))
        }

        if matchesHost(host, suffixes: ["youtube.com", "youtu.be"]) {
            return compose(
                platform: "YouTube",
                identifier: youTubeIdentifier(
                    host: host,
                    pathSegments: pathSegments,
                    queryItems: URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                )
            )
        }

        if matchesHost(host, suffixes: ["x.com", "twitter.com"]) {
            return compose(
                platform: "X",
                identifier: atHandle(firstMeaningfulSegment(pathSegments, skipping: Self.xSkippedSegments))
            )
        }

        if matchesHost(host, suffixes: ["facebook.com", "fb.com", "fb.me"]) {
            return compose(platform: "Facebook", identifier: facebookIdentifier(pathSegments: pathSegments))
        }

        if matchesHost(host, suffixes: ["apps.apple.com", "itunes.apple.com"]) {
            return compose(
                platform: "App Store",
                identifier: appStoreIdentifier(
                    pathSegments: pathSegments,
                    queryItems: URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                )
            )
        }

        return compose(
            platform: stripWWW(host),
            identifier: websiteIdentifier(from: pathSegments)
        )
    }

    // MARK: - Compose / truncate (25-char rule)

    /// `platform • identifier`, capped at 25 chars. Only the identifier is middle-truncated.
    static func compose(platform: String, identifier: String?) -> String {
        let platformPart = truncateMiddle(platform, maxLength: maxLength)
        guard let identifier, !identifier.isEmpty else {
            return platformPart
        }

        let full = platformPart + separator + identifier
        if full.count <= maxLength {
            return full
        }

        let budget = maxLength - platformPart.count - separator.count
        guard budget > 0 else {
            return platformPart
        }

        return platformPart + separator + truncateMiddle(identifier, maxLength: budget)
    }

    /// Keeps the start and end of `string`, inserting `…` in the middle when over `maxLength`.
    static func truncateMiddle(_ string: String, maxLength: Int) -> String {
        guard maxLength > 0 else { return "" }
        guard string.count > maxLength else { return string }

        let ellipsis = "…"
        if maxLength == 1 {
            return ellipsis
        }

        let available = maxLength - ellipsis.count
        guard available > 0 else { return ellipsis }

        let headCount = (available + 1) / 2
        let tailCount = available - headCount
        let start = String(string.prefix(headCount))
        let end = tailCount > 0 ? String(string.suffix(tailCount)) : ""
        return start + ellipsis + end
    }

    // MARK: - Platform identifiers

    private static let xSkippedSegments: Set<String> = ["i", "intent", "share", "home", "explore", "search"]
    private static let facebookSkippedSegments: Set<String> = [
        "profile.php", "people", "pages", "groups", "watch", "reel", "share", "story.php"
    ]
    private static let genericSkippedSegments: Set<String> = [
        "p", "reel", "reels", "stories", "share", "s", "video", "channel", "c", "user", "u", "@"
    ]
    private static let websiteSkippedSegments: Set<String> = [
        "pages", "page", "p", "index", "index.html", "index.htm", "www", "home"
    ]

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
            return compose(platform: "WhatsApp", identifier: nil)
        }

        let suffix = String(phoneDigits.suffix(4))
        return compose(platform: "WhatsApp", identifier: "••••\(suffix)")
    }

    private static func tikTokIdentifier(pathSegments: [String]) -> String? {
        guard let first = pathSegments.first, !first.isEmpty else { return nil }
        if first.hasPrefix("@") { return first }
        if first.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." })
            && first.count >= 2
            && first.contains(where: \.isLetter) {
            return "@\(first)"
        }
        return first
    }

    private static func linkedInIdentifier(pathSegments: [String]) -> String? {
        guard let first = pathSegments.first?.lowercased() else { return nil }
        if first == "in" || first == "company" || first == "school",
           let slug = pathSegments.dropFirst().first {
            return readablePathText(slug)
        }
        return readablePathText(pathSegments[0])
    }

    private static func payPalIdentifier(host: String, pathSegments: [String]) -> String? {
        if host.hasSuffix("paypal.me"), let username = pathSegments.first {
            return username
        }
        if let paypalmeIndex = pathSegments.firstIndex(where: { $0.lowercased() == "paypalme" }),
           paypalmeIndex + 1 < pathSegments.count {
            return pathSegments[paypalmeIndex + 1]
        }
        return firstMeaningfulSegment(pathSegments, skipping: ["donate", "cgi-bin", "webapps"])
    }

    private static func youTubeIdentifier(
        host: String,
        pathSegments: [String],
        queryItems: [URLQueryItem]?
    ) -> String? {
        if host.hasSuffix("youtu.be"), let id = pathSegments.first {
            return id
        }
        if let first = pathSegments.first {
            if first.hasPrefix("@") {
                return ensureAtPrefix(first)
            }
            let lower = first.lowercased()
            if lower == "channel" || lower == "c" || lower == "user",
               let slug = pathSegments.dropFirst().first {
                return slug
            }
            if lower == "watch",
               let videoID = queryItems?.first(where: { $0.name == "v" })?.value,
               !videoID.isEmpty {
                return videoID
            }
            if lower == "shorts", let id = pathSegments.dropFirst().first {
                return id
            }
        }
        return firstMeaningfulSegment(pathSegments)
    }

    private static func facebookIdentifier(pathSegments: [String]) -> String? {
        firstMeaningfulSegment(pathSegments, skipping: Self.facebookSkippedSegments)
    }

    private static func appStoreIdentifier(
        pathSegments: [String],
        queryItems: [URLQueryItem]?
    ) -> String? {
        let lowered = pathSegments.map { $0.lowercased() }
        let action = queryItems?.first(where: { $0.name.lowercased() == "action" })?.value?.lowercased()
        if action == "write-review"
            || lowered.contains(where: { $0.contains("review") || $0 == "write-review" }) {
            return "Review"
        }
        // apps.apple.com/app/name/id123 → prefer the app name slug
        if let appIndex = lowered.firstIndex(of: "app"),
           appIndex + 1 < pathSegments.count {
            let candidate = pathSegments[appIndex + 1]
            if !candidate.lowercased().hasPrefix("id") {
                return readablePathText(candidate)
            }
        }
        if let last = pathSegments.last, !last.lowercased().hasPrefix("id") {
            return readablePathText(last)
        }
        return nil
    }

    private static func websiteIdentifier(from pathSegments: [String]) -> String? {
        let meaningful = pathSegments.filter { segment in
            let lower = segment.lowercased()
            return !Self.websiteSkippedSegments.contains(lower)
        }
        guard let last = meaningful.last, !last.isEmpty else { return nil }
        return readablePathText(last)
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

    private static func atHandle(_ handle: String?) -> String? {
        guard let handle, !handle.isEmpty else { return nil }
        return ensureAtPrefix(handle)
    }

    private static func ensureAtPrefix(_ handle: String) -> String {
        if handle.hasPrefix("@") { return handle }
        return "@\(handle)"
    }

    /// Percent-decodes, turns `-` / `_` into spaces, and title-cases words.
    private static func readablePathText(_ raw: String) -> String {
        let decoded = raw.removingPercentEncoding ?? raw
        let separators = CharacterSet(charactersIn: "-_")
        let words = decoded
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return decoded }
        return words
            .map { word in
                guard let first = word.first else { return word }
                return String(first).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }
}
