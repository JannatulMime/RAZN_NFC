//
//  SemanticVersion.swift
//  RAZN NFC
//

import Foundation

/// Numeric release version (e.g. `5.0`, `1.10.0`) comparable component-wise.
struct SemanticVersion: Comparable, Equatable, Sendable {
    let components: [Int]

    init?(string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return nil }

        var values: [Int] = []
        values.reserveCapacity(parts.count)
        for part in parts {
            let piece = String(part)
            guard !piece.isEmpty, piece.allSatisfy(\.isNumber), let value = Int(piece) else {
                return nil
            }
            values.append(value)
        }
        components = values
    }

    static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return false }
        }
        return true
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}
