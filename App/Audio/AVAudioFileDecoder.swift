import AVFoundation
import VinylSetBuilderCore

/// The only audio-decoding code in this project, and the other half of BPM-08's seam.
///
/// A 30-second SoundCloud preview arrives as MP3 bytes. `AVAudioFile` needs a file, so one is
/// written to the system temporary directory and **deleted before this function returns** —
/// BPM-04's "the audio is not retained" is enforced by never keeping it, not by remembering to
/// clean up later.
struct AVAudioFileDecoder: AudioDecoding {
    func decodeMono(_ data: Data) async throws -> (samples: [Float], sampleRate: Double) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vsb-\(UUID().uuidString).mp3")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frames = AVAudioFrameCount(file.length)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            return ([], format.sampleRate)
        }
        try file.read(into: buffer)
        guard let channels = buffer.floatChannelData else { return ([], format.sampleRate) }

        let count = Int(buffer.frameLength)
        let channelCount = Int(format.channelCount)
        var mono = [Float](repeating: 0, count: count)
        for channel in 0..<channelCount {
            let samples = channels[channel]
            for index in 0..<count { mono[index] += samples[index] }
        }
        if channelCount > 1 {
            let scale = 1 / Float(channelCount)
            for index in 0..<count { mono[index] *= scale }
        }
        return (mono, format.sampleRate)
    }
}
