//
//  ClipboardTextInserterTests.swift
//  DevWisprTests
//

import Testing
@testable import DevWispr

/// ClipboardTextInserter relies on CGEvent posting which requires:
/// - Accessibility permissions granted to the test runner
/// - A window server (not available in headless CI)
///
/// This is intentionally left as a manual-only test.
/// To verify: run the app, trigger a paste, and confirm text appears in the target field.
@Suite("ClipboardTextInserter Tests (Manual Only)")
struct ClipboardTextInserterTests {
    @Test("Placeholder — see doc comment for manual test instructions")
    func placeholder() {
        // Manual verification only. See suite documentation.
    }
}
