//
//  TranscriptItem.swift
//  DevWispr
//

import Foundation

struct TranscriptItem: Identifiable, Equatable, Hashable, Codable {
    let id: UUID
    let createdAt: Date
    let text: String
    let inputLanguage: Language
    let outputLanguage: Language
    let appBundleId: String?
    let appName: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        text: String,
        inputLanguage: Language,
        outputLanguage: Language,
        appBundleId: String? = nil,
        appName: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.inputLanguage = inputLanguage
        self.outputLanguage = outputLanguage
        self.appBundleId = appBundleId
        self.appName = appName
    }

    #if DEBUG
    static let previewItems: [TranscriptItem] = [
        TranscriptItem(text: "The deployment is scheduled for tomorrow morning at 9 AM.", inputLanguage: .english, outputLanguage: .english),
        TranscriptItem(text: "Can you send me the latest report by end of day?", inputLanguage: .english, outputLanguage: .english),
        TranscriptItem(text: "Schedule the meeting for Thursday at 2 PM.", inputLanguage: .english, outputLanguage: .english),
    ]
    #endif
}
