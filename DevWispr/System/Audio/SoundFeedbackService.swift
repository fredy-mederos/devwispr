//
//  SoundFeedbackService.swift
//  DevWispr
//

import AppKit

final class DefaultSoundFeedbackService: SoundFeedbackService {
    func playRecordingStarted() {
        NSSound(named: "Tink")?.play()
    }
}
