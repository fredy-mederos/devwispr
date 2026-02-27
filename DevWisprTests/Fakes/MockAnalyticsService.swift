//
//  MockAnalyticsService.swift
//  DevWisprTests
//

import Foundation
@testable import DevWispr

final class MockAnalyticsService: AnalyticsService {
    var loggedEvents: [AnalyticsEvent] = []
    var logEventCallCount = 0
    var userProperties: [AnalyticsUserProperty: String?] = [:]
    var setUserPropertyCallCount = 0

    func logEvent(_ event: AnalyticsEvent) {
        logEventCallCount += 1
        loggedEvents.append(event)
    }

    func setUserProperty(_ property: AnalyticsUserProperty, value: String?) {
        setUserPropertyCallCount += 1
        userProperties[property] = value
    }
}
