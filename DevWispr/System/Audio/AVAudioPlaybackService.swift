//
//  AVAudioPlaybackService.swift
//  DevWispr
//

import AVFoundation
import Foundation

extension Notification.Name {
    static let audioPlaybackDidFinish = Notification.Name("devwispr.audioPlaybackDidFinish")
}

final class AVAudioPlaybackService: NSObject, AudioPlaybackService {
    private var player: AVAudioPlayer?
    private(set) var currentURL: URL?

    var isPlaying: Bool {
        player?.isPlaying == true
    }

    func play(url: URL) throws {
        let nextPlayer = try AVAudioPlayer(contentsOf: url)
        nextPlayer.delegate = self
        nextPlayer.prepareToPlay()

        player?.stop()
        player = nextPlayer
        currentURL = url
        nextPlayer.play()
    }

    func stop() {
        guard currentURL != nil || player != nil else { return }
        let finishedURL = currentURL
        player?.stop()
        player = nil
        currentURL = nil
        NotificationCenter.default.post(name: .audioPlaybackDidFinish, object: finishedURL)
    }
}

extension AVAudioPlaybackService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finishedURL = currentURL
        self.player = nil
        currentURL = nil
        NotificationCenter.default.post(name: .audioPlaybackDidFinish, object: finishedURL)
    }
}
