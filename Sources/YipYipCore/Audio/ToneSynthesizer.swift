import Foundation

/// Generates the app's audio cues as in-memory WAV data.
///
/// The macOS alert sounds (Tink, Pop) are alert-shaped — they read as "something
/// went wrong" when they fire on every copy. These are soft sine tones with a
/// fast attack and an exponential tail instead, quiet enough to sit under typing.
public enum ToneSynthesizer {
    public enum Cue: Sendable, CaseIterable {
        /// One soft, high tick.
        case capture
        /// Two rising notes — reads as "landed".
        case paste
    }

    public static let sampleRate = 44_100.0

    /// A single note: frequency, when it starts, how long it rings, how loud.
    struct Note {
        let frequency: Double
        let start: Double
        let duration: Double
        let gain: Double
    }

    public static func wav(for cue: Cue) -> Data {
        let (notes, length) = score(for: cue)
        return wavData(samples: samples(notes: notes, length: length))
    }

    static func score(for cue: Cue) -> (notes: [Note], length: Double) {
        switch cue {
        case .capture:
            // C6, with a quiet octave above for sparkle.
            return ([
                Note(frequency: 1046.50, start: 0, duration: 0.13, gain: 0.22),
                Note(frequency: 2093.00, start: 0, duration: 0.07, gain: 0.06),
            ], 0.16)
        case .paste:
            // G5 then C6.
            return ([
                Note(frequency: 783.99, start: 0, duration: 0.10, gain: 0.20),
                Note(frequency: 1046.50, start: 0.055, duration: 0.14, gain: 0.20),
            ], 0.22)
        }
    }

    static func samples(notes: [Note], length: Double) -> [Float] {
        let frameCount = Int(length * sampleRate)
        var samples = [Float](repeating: 0, count: frameCount)

        for note in notes {
            let startFrame = Int(note.start * sampleRate)
            let noteFrames = Int(note.duration * sampleRate)

            for offset in 0..<noteFrames {
                let frame = startFrame + offset
                guard frame < frameCount else { break }

                let time = Double(offset) / sampleRate
                // Exponential decay, plus a 4 ms fade-in so the onset does not click.
                let decay = exp(-time / (note.duration * 0.32))
                let attack = min(1, time / 0.004)
                let value = sin(2 * .pi * note.frequency * time) * decay * attack * note.gain
                samples[frame] += Float(value)
            }
        }

        // Guard against the summed notes clipping.
        let peak = samples.map(abs).max() ?? 0
        if peak > 0.99 {
            let scale = 0.99 / peak
            for index in samples.indices { samples[index] *= scale }
        }
        return samples
    }

    /// Wraps mono 16-bit PCM in a WAV container so it can be played straight
    /// from memory, with no bundled asset file.
    static func wavData(samples: [Float]) -> Data {
        let bitsPerSample = 16
        let channels = 1
        let byteRate = Int(sampleRate) * channels * bitsPerSample / 8
        let dataSize = samples.count * bitsPerSample / 8

        var data = Data()
        func append(_ string: String) { data.append(contentsOf: string.utf8) }
        func append32(_ value: Int) {
            data.append(contentsOf: withUnsafeBytes(of: UInt32(value).littleEndian, Array.init))
        }
        func append16(_ value: Int) {
            data.append(contentsOf: withUnsafeBytes(of: UInt16(value).littleEndian, Array.init))
        }

        append("RIFF")
        append32(36 + dataSize)
        append("WAVE")

        append("fmt ")
        append32(16)            // PCM header size
        append16(1)             // PCM format
        append16(channels)
        append32(Int(sampleRate))
        append32(byteRate)
        append16(channels * bitsPerSample / 8)
        append16(bitsPerSample)

        append("data")
        append32(dataSize)
        for sample in samples {
            let clamped = max(-1, min(1, sample))
            let value = Int16(clamped * Float(Int16.max))
            data.append(contentsOf: withUnsafeBytes(of: value.littleEndian, Array.init))
        }
        return data
    }
}
