//
//  DevWisprUITests.swift
//  DevWisprUITests
//

import XCTest

final class DevWisprUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
    }

    // MARK: - Tests

    func testPopoverShowsConfiguredState() {
        app.launch()

        let popoverWindow = app.windows["DevWispr"]
        XCTAssertTrue(popoverWindow.waitForExistence(timeout: 5))

        // Status should show "Idle" — query by text content
        XCTAssertTrue(
            popoverWindow.staticTexts["Idle"].waitForExistence(timeout: 3),
            "Status label should show 'Idle'"
        )

        // API key should show "Configured" — query by text content
        XCTAssertTrue(
            popoverWindow.staticTexts["Configured"].waitForExistence(timeout: 3),
            "API key status should show 'Configured'"
        )

        // API key button should show "Change"
        let apiKeyButton = popoverWindow.buttons["popover_apiKey_button"]
        XCTAssertTrue(apiKeyButton.waitForExistence(timeout: 3))
    }

    func testPopoverAPIKeySheetFlow() {
        app.launch()

        let popoverWindow = app.windows["DevWispr"]
        XCTAssertTrue(popoverWindow.waitForExistence(timeout: 5))

        // Tap Change to open sheet
        let apiKeyButton = popoverWindow.buttons["popover_apiKey_button"]
        XCTAssertTrue(apiKeyButton.waitForExistence(timeout: 3))
        apiKeyButton.click()

        // Sheet should appear with SecureField
        let sheetField = popoverWindow.secureTextFields["sheet_apiKey_field"]
        XCTAssertTrue(sheetField.waitForExistence(timeout: 3))
        sheetField.click()
        sheetField.typeText("sk-new-key-67890")

        // Tap Save in sheet
        let sheetSave = popoverWindow.buttons["sheet_save_button"]
        XCTAssertTrue(sheetSave.waitForExistence(timeout: 2))
        sheetSave.click()

        // Sheet should dismiss, API key should still be configured
        XCTAssertTrue(
            popoverWindow.staticTexts["Configured"].waitForExistence(timeout: 3),
            "API key status should still show 'Configured' after changing key"
        )
    }

    func testResetToOpenAIFromCustomProvider() {
        app.launchArguments.append("--ui-test-custom-provider")
        app.launch()

        let popoverWindow = app.windows["DevWispr"]
        XCTAssertTrue(popoverWindow.waitForExistence(timeout: 5))

        // Reset to OpenAI button should be visible
        let resetButton = popoverWindow.buttons["popover_resetProvider_button"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 3), "Reset to OpenAI button should be visible")

        // Tap it
        resetButton.click()

        // Button should disappear (provider reset to OpenAI)
        let disappeared = NSPredicate(format: "exists == false")
        expectation(for: disappeared, evaluatedWith: resetButton)
        waitForExpectations(timeout: 5)

        // API key status should show "Not set" after reset (resetToOpenAI clears the key)
        // The full text is "Not set — tap to set up" but we check by identifier + content
        let notSetText = popoverWindow.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'Not set' OR value CONTAINS[c] 'Not set'")
        )
        // Also try matching by the element being present after the reset
        let notSetDirect = popoverWindow.staticTexts["Not set — tap to set up"]
        let notSetShort = popoverWindow.staticTexts["Not set"]
        XCTAssertTrue(
            notSetDirect.waitForExistence(timeout: 3) || notSetShort.exists || notSetText.count > 0,
            "API key status should show 'Not set' after reset"
        )
    }
}
