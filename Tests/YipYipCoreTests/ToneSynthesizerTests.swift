import Foundation
import Testing
@testable import YipYipCore

@Suite("ToneSynthesizer")
struct ToneSynthesizerTests {
    @Test("Every cue produces a well-formed WAV", arguments: ToneSynthesizer.Cue.allCases)
    func wavHeader(cue: ToneSynthesizer.Cue) throws {
        let data = ToneSynthesizer.wav(for: cue)

        #expect(data.prefix(4) == Data("RIFF".utf8))
        #expect(data[8..<12] == Data("WAVE".utf8))

        let declaredSize = data[4..<8].withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        #expect(Int(declaredSize) == data.count - 8)

        let dataChunkSize = data[40..<44].withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        #expect(Int(dataChunkSize) == data.count - 44)
    }

    @Test("Cues stay short enough to not overlap typing")
    func duration() {
        for cue in ToneSynthesizer.Cue.allCases {
            let frames = (ToneSynthesizer.wav(for: cue).count - 44) / 2
            let seconds = Double(frames) / ToneSynthesizer.sampleRate
            #expect(seconds > 0.05)
            #expect(seconds < 0.35)
        }
    }

    @Test("Tones fade in and out instead of clicking")
    func envelope() {
        let (notes, length) = ToneSynthesizer.score(for: .capture)
        let samples = ToneSynthesizer.samples(notes: notes, length: length)

        // A hard onset or a chopped tail is what makes a cue sound like an error.
        #expect(abs(samples.first ?? 1) < 0.01)
        #expect(abs(samples.last ?? 1) < 0.01)
    }

    @Test("Output never clips")
    func headroom() {
        for cue in ToneSynthesizer.Cue.allCases {
            let (notes, length) = ToneSynthesizer.score(for: cue)
            let peak = ToneSynthesizer.samples(notes: notes, length: length).map(abs).max() ?? 0
            #expect(peak > 0.05)
            #expect(peak <= 0.99)
        }
    }
}
