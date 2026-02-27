//
//  UpdateInfo.swift
//  DevWispr
//

import Foundation

struct UpdateInfo {
    let latestVersion: String
    let currentVersion: String
    let releaseURL: URL
    let releaseNotes: String?

    /// Compares two semantic version strings component-by-component.
    /// Returns `true` when `lhs` is strictly less than `rhs`.
    static func isVersion(_ lhs: String, lessThan rhs: String) -> Bool {
        let lhsParts = lhs.split(separator: ".").compactMap { Int($0) }
        let rhsParts = rhs.split(separator: ".").compactMap { Int($0) }
        let count = max(lhsParts.count, rhsParts.count)
        for i in 0..<count {
            let l = i < lhsParts.count ? lhsParts[i] : 0
            let r = i < rhsParts.count ? rhsParts[i] : 0
            if l < r { return true }
            if l > r { return false }
        }
        return false
    }
}
