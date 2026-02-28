//
//  FailedRecordingItem.swift
//  DevWispr
//

import Foundation

struct FailedRecordingItem: Identifiable, Equatable, Hashable, Codable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    let audioFileName: String
    let fileSizeBytes: Int64
    let durationSeconds: TimeInterval
    var lastError: String
    var retryCount: Int

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        audioFileName: String,
        fileSizeBytes: Int64,
        durationSeconds: TimeInterval,
        lastError: String,
        retryCount: Int = 0
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.audioFileName = audioFileName
        self.fileSizeBytes = fileSizeBytes
        self.durationSeconds = durationSeconds
        self.lastError = lastError
        self.retryCount = retryCount
    }
}
