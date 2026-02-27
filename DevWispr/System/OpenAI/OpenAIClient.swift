//
//  OpenAIClient.swift
//  DevWispr
//

import Foundation

struct OpenAIClientConfiguration {
    let baseURLProvider: () -> URL
    let apiKeyProvider: () -> String?
}

final class OpenAIClient {
    enum ClientError: LocalizedError {
        case invalidURL(String)
        case missingAPIKey
        case invalidResponse
        case requestFailed(Int, String?)
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .invalidURL(let path):
                return "Invalid URL for path: \(path)"
            case .missingAPIKey:
                return "Missing OpenAI API key"
            case .invalidResponse:
                return "Invalid server response"
            case .requestFailed(let status, let message):
                if let message, !message.isEmpty {
                    return "OpenAI request failed (\(status)): \(message)"
                }
                return "OpenAI request failed (\(status))"
            case .decodingFailed:
                return "Failed to decode OpenAI response"
            }
        }
    }

    private let configuration: OpenAIClientConfiguration
    private let session: URLSession

    init(configuration: OpenAIClientConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func makeRequest(path: String, method: String, headers: [String: String] = [:], body: Data? = nil) throws -> URLRequest {
        let baseString = configuration.baseURLProvider().absoluteString
        let normalizedBase = baseString.hasSuffix("/") ? baseString : "\(baseString)/"
        debugLog("OpenAIClient: base URL = \(baseString)")
        debugLog("OpenAIClient: normalized base URL = \(normalizedBase)")
        guard let baseURL = URL(string: normalizedBase) else {
            throw ClientError.invalidURL(normalizedBase)
        }
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw ClientError.invalidURL(path)
        }
        debugLog("OpenAIClient: final URL = \(url.absoluteString)")

        guard let apiKey = configuration.apiKeyProvider(), !apiKey.isEmpty else {
            throw ClientError.missingAPIKey
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        debugLog("OpenAIClient: \(method) \(url.absoluteString)")
        return request
    }

    func perform(_ request: URLRequest) async throws -> Data {
        debugLog("OpenAIClient: sending request to \(request.url?.absoluteString ?? "nil")")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            debugLog("OpenAIClient: invalid response (not HTTPURLResponse)")
            throw ClientError.invalidResponse
        }

        debugLog("OpenAIClient: response status = \(http.statusCode)")
        guard (200...299).contains(http.statusCode) else {
            let message = OpenAIClient.parseErrorMessage(from: data)
            let body = String(data: data.prefix(500), encoding: .utf8) ?? "<non-utf8>"
            debugLog("OpenAIClient: error response body = \(body)")
            throw ClientError.requestFailed(http.statusCode, message)
        }
        return data
    }

    static func parseErrorMessage(from data: Data) -> String? {
        try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data).error?.message
    }
}
