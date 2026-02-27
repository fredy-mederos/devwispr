//
//  MockTextInserter.swift
//  DevWisprTests
//

import Foundation
@testable import DevWispr

final class MockTextInserter: TextInserter {
    var shouldThrow: Error?
    var insertedTexts: [String] = []
    var insertCallCount = 0

    func insertText(_ text: String) async throws {
        insertCallCount += 1
        if let error = shouldThrow { throw error }
        insertedTexts.append(text)
    }
}
