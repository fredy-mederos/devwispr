//
//  MockUpdateChecker.swift
//  DevWisprTests
//

import Foundation
@testable import DevWispr

final class MockUpdateChecker: UpdateChecker {
    var shouldThrow: Error?
    var result: UpdateInfo?
    var checkCallCount = 0
    var onCheck: (() -> Void)?

    func checkForUpdate() async throws -> UpdateInfo? {
        checkCallCount += 1
        onCheck?()
        if let error = shouldThrow { throw error }
        return result
    }
}
