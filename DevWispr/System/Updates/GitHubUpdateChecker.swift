//
//  GitHubUpdateChecker.swift
//  DevWispr
//

import Foundation

final class GitHubUpdateChecker: UpdateChecker {

    #if DEBUG
    private static let defaultThrottleInterval: TimeInterval = 60
    #else
    private static let defaultThrottleInterval: TimeInterval = 43_200
    #endif

    private let owner: String
    private let repo: String
    private let session: URLSession
    private let currentVersionProvider: () -> String?
    private let throttleInterval: TimeInterval
    private let lastCheckDateProvider: () -> Date?
    private let onChecked: (Date) -> Void

    init(
        owner: String = AppConfig.gitHubRepoOwner,
        repo: String = AppConfig.gitHubRepoName,
        session: URLSession = .shared,
        currentVersionProvider: @escaping () -> String? = {
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        },
        throttleInterval: TimeInterval = defaultThrottleInterval,
        lastCheckDateProvider: @escaping () -> Date? = {
            UserDefaults.standard.object(forKey: "lastUpdateCheckDate") as? Date
        },
        onChecked: @escaping (Date) -> Void = { date in
            UserDefaults.standard.set(date, forKey: "lastUpdateCheckDate")
        }
    ) {
        self.owner = owner
        self.repo = repo
        self.session = session
        self.currentVersionProvider = currentVersionProvider
        self.throttleInterval = throttleInterval
        self.lastCheckDateProvider = lastCheckDateProvider
        self.onChecked = onChecked
    }

    func checkForUpdate() async throws -> UpdateInfo? {
        // Throttle: skip if checked recently
        if let lastCheck = lastCheckDateProvider(),
           Date().timeIntervalSince(lastCheck) < throttleInterval {
            debugLog("Update check throttled — last check: \(lastCheck)")
            return nil
        }

        guard let currentVersion = currentVersionProvider() else {
            debugLog("Update check skipped — could not read current version")
            return nil
        }
        debugLog("Update check starting — current version: \(currentVersion)")

        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        debugLog("Update check URL: \(url.absoluteString)")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            debugLog("Update check failed — non-HTTP response")
            return nil
        }
        debugLog("Update check response: HTTP \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            debugLog("Update check failed — response body: \(String(data: data, encoding: .utf8) ?? "<binary>")")
            return nil
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let latestVersion = release.tagName.hasPrefix("v")
            ? String(release.tagName.dropFirst())
            : release.tagName

        onChecked(Date())

        debugLog("Update check — local: \(currentVersion), remote: \(latestVersion), updateAvailable: \(UpdateInfo.isVersion(currentVersion, lessThan: latestVersion))")

        guard UpdateInfo.isVersion(currentVersion, lessThan: latestVersion) else {
            return nil
        }

        return UpdateInfo(
            latestVersion: latestVersion,
            currentVersion: currentVersion,
            releaseURL: release.htmlURL,
            releaseNotes: release.body
        )
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let body: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case body
    }
}
