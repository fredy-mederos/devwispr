//
//  UpdateCheckerTests.swift
//  DevWisprTests
//

import Foundation
import Testing
@testable import DevWispr

@Suite("UpdateInfo version comparison")
struct UpdateInfoVersionTests {

    @Test("older version is less than newer version")
    func olderLessThanNewer() {
        #expect(UpdateInfo.isVersion("0.8", lessThan: "0.10"))
        #expect(UpdateInfo.isVersion("1.0", lessThan: "1.1"))
        #expect(UpdateInfo.isVersion("1.0.0", lessThan: "1.0.1"))
        #expect(UpdateInfo.isVersion("0.9", lessThan: "1.0"))
    }

    @Test("same version is not less than itself")
    func sameVersionNotLess() {
        #expect(!UpdateInfo.isVersion("1.0", lessThan: "1.0"))
        #expect(!UpdateInfo.isVersion("0.10", lessThan: "0.10"))
        #expect(!UpdateInfo.isVersion("2.3.4", lessThan: "2.3.4"))
    }

    @Test("newer version is not less than older version")
    func newerNotLessThanOlder() {
        #expect(!UpdateInfo.isVersion("1.1", lessThan: "1.0"))
        #expect(!UpdateInfo.isVersion("2.0", lessThan: "1.9"))
        #expect(!UpdateInfo.isVersion("0.10", lessThan: "0.8"))
    }

    @Test("different component counts handled correctly")
    func differentComponentCounts() {
        #expect(UpdateInfo.isVersion("1.0", lessThan: "1.0.1"))
        #expect(!UpdateInfo.isVersion("1.0.1", lessThan: "1.0"))
        #expect(!UpdateInfo.isVersion("1.0.0", lessThan: "1.0"))
    }
}

@Suite("AppState update check integration")
struct AppStateUpdateTests {

    @MainActor
    private func makeSUT(mock: MockUpdateChecker = MockUpdateChecker()) -> (AppState, MockUpdateChecker) {
        let container = AppContainer(
            audioRecorder: MockAudioRecorder(),
            transcriptionService: MockTranscriptionService(),
            translationService: MockTranslationService(),
            permissionsManager: MockPermissionsManager(),
            hotkeyManager: MockHotkeyManager(),
            settingsStore: MockSettingsStore(),
            updateChecker: mock
        )
        return (AppState(container: container), mock)
    }

    @Test("checkForUpdates sets availableUpdate when update exists")
    @MainActor
    func checkSetsAvailableUpdate() async {
        let mock = MockUpdateChecker()
        mock.result = UpdateInfo(
            latestVersion: "2.0",
            currentVersion: "1.0",
            releaseURL: URL(string: "https://github.com/fredy-mederos/devwispr/releases/tag/v2.0")!,
            releaseNotes: "New features"
        )
        let (appState, _) = makeSUT(mock: mock)

        await appState.checkForUpdates()

        #expect(mock.checkCallCount == 1)
        #expect(appState.availableUpdate?.latestVersion == "2.0")
        #expect(appState.availableUpdate?.releaseNotes == "New features")
    }

    @Test("checkForUpdates leaves availableUpdate nil when no update")
    @MainActor
    func checkNoUpdate() async {
        let (appState, mock) = makeSUT()
        mock.result = nil

        await appState.checkForUpdates()

        #expect(mock.checkCallCount == 1)
        #expect(appState.availableUpdate == nil)
    }

    @Test("checkForUpdates handles errors gracefully")
    @MainActor
    func checkHandlesError() async {
        let mock = MockUpdateChecker()
        mock.shouldThrow = URLError(.notConnectedToInternet)
        let (appState, _) = makeSUT(mock: mock)

        await appState.checkForUpdates()

        #expect(mock.checkCallCount == 1)
        #expect(appState.availableUpdate == nil)
        #expect(appState.status == .idle)
    }

    // MARK: - UpdateCheckStatus tests

    @Test("updateCheckStatus starts as idle")
    @MainActor
    func statusStartsIdle() {
        let (appState, _) = makeSUT()
        #expect(appState.updateCheckStatus == .idle)
    }

    @Test("updateCheckStatus becomes checking during the call")
    @MainActor
    func statusBecomesCheckingDuringCall() async {
        let mock = MockUpdateChecker()
        let (appState, _) = makeSUT(mock: mock)

        mock.onCheck = {
            #expect(appState.updateCheckStatus == .checking)
        }

        await appState.checkForUpdates()
    }

    @Test("updateCheckStatus becomes available when update found")
    @MainActor
    func statusBecomesAvailable() async {
        let mock = MockUpdateChecker()
        mock.result = UpdateInfo(
            latestVersion: "2.0",
            currentVersion: "1.0",
            releaseURL: URL(string: "https://github.com/fredy-mederos/devwispr/releases/tag/v2.0")!,
            releaseNotes: nil
        )
        let (appState, _) = makeSUT(mock: mock)

        await appState.checkForUpdates()

        #expect(appState.updateCheckStatus == .available)
    }

    @Test("updateCheckStatus becomes upToDate when no update")
    @MainActor
    func statusBecomesUpToDate() async {
        let mock = MockUpdateChecker()
        mock.result = nil
        let (appState, _) = makeSUT(mock: mock)

        await appState.checkForUpdates()

        #expect(appState.updateCheckStatus == .upToDate)
    }

    @Test("updateCheckStatus resets to idle on error")
    @MainActor
    func statusResetsToIdleOnError() async {
        let mock = MockUpdateChecker()
        mock.shouldThrow = URLError(.notConnectedToInternet)
        let (appState, _) = makeSUT(mock: mock)

        await appState.checkForUpdates()

        #expect(appState.updateCheckStatus == .idle)
    }
}
