import AVFoundation
import YipYipCore
import Foundation

/// Plays the synthesised cues. Players are built once and rewound on replay, so
/// rapid copying does not spawn a decoder per event.
@MainActor
enum SoundPlayer {
    enum Effect {
        case copy
        case paste

        fileprivate var cue: ToneSynthesizer.Cue {
            switch self {
            case .copy: .capture
            case .paste: .paste
            }
        }
    }

    private static var players: [ToneSynthesizer.Cue: AVAudioPlayer] = [:]

    static func play(_ effect: Effect) {
        guard let player = player(for: effect.cue) else { return }
        player.currentTime = 0
        player.play()
    }

    private static func player(for cue: ToneSynthesizer.Cue) -> AVAudioPlayer? {
        if let cached = players[cue] { return cached }

        guard let player = try? AVAudioPlayer(data: ToneSynthesizer.wav(for: cue)) else { return nil }
        player.volume = 0.5
        player.prepareToPlay()
        players[cue] = player
        return player
    }
}
