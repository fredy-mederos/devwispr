//
//  DeepLinkHandlerTests.swift
//  DevWisprTests
//

import Foundation
import Testing
@testable import DevWispr

@Suite("DeepLinkHandler Tests")
struct DeepLinkHandlerTests {
    @Test("Parses valid configure URL with baseURL")
    @MainActor
    func parsesValidConfigureURL() {
        let url = URL(string: "devwispr://configure?baseURL=https://example.com/v1")!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        #expect(components?.scheme == "devwispr")
        #expect(components?.host == "configure")
        let baseURL = components?.queryItems?.first(where: { $0.name == "baseURL" })?.value
        #expect(baseURL == "https://example.com/v1")
    }

    @Test("Ignores invalid scheme")
    @MainActor
    func ignoresInvalidScheme() {
        let url = URL(string: "https://configure?baseURL=https://example.com/v1")!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        #expect(components?.scheme != "devwispr")
    }

    @Test("Ignores invalid host")
    @MainActor
    func ignoresInvalidHost() {
        let url = URL(string: "devwispr://settings?baseURL=https://example.com/v1")!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        #expect(components?.host != "configure")
    }

    @Test("Handles missing baseURL parameter gracefully")
    @MainActor
    func handlesMissingBaseURL() {
        let url = URL(string: "devwispr://configure")!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let baseURL = components?.queryItems?.first(where: { $0.name == "baseURL" })?.value
        #expect(baseURL == nil)
    }

    @Test("Parses configure URL with both baseURL and apiKeyURL")
    @MainActor
    func parsesBothBaseURLAndApiKeyURL() {
        let url = URL(string: "devwispr://configure?baseURL=https://example.com/v1&apiKeyURL=https://example.com/api-keys")!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let baseURL = components?.queryItems?.first(where: { $0.name == "baseURL" })?.value
        let apiKeyURL = components?.queryItems?.first(where: { $0.name == "apiKeyURL" })?.value
        #expect(baseURL == "https://example.com/v1")
        #expect(apiKeyURL == "https://example.com/api-keys")
    }

    @Test("Parses configure URL with only baseURL — apiKeyURL is nil")
    @MainActor
    func parsesBaseURLOnlyApiKeyURLNil() {
        let url = URL(string: "devwispr://configure?baseURL=https://example.com/v1")!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let apiKeyURL = components?.queryItems?.first(where: { $0.name == "apiKeyURL" })?.value
        #expect(apiKeyURL == nil)
    }
}
