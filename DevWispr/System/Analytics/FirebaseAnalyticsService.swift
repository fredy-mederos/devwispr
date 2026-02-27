//
//  FirebaseAnalyticsService.swift
//  DevWispr
//

import FirebaseAnalytics

final class FirebaseAnalyticsService: AnalyticsService {
    func logEvent(_ event: AnalyticsEvent) {
        Analytics.logEvent(event.name, parameters: event.parameters)
    }

    func setUserProperty(_ property: AnalyticsUserProperty, value: String?) {
        Analytics.setUserProperty(value, forName: property.rawValue)
    }
}
