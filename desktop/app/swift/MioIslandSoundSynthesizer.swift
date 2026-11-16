import Foundation
import AVFAudio

@objc public final class MioIslandSoundSynthesizer: NSObject, @unchecked Sendable {
    public static let shared = MioIslandSoundSynthesizer()

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var isEngineSetup = false
    private let lock = NSLock()

    private enum Note {
        static let A3: Float = 220.00
        static let C4: Float = 261.63
        static let E4: Float = 329.63
        static let G4: Float = 392.00
        static let C5: Float = 523.25
        static let E5: Float = 659.25
        static let F5: Float = 698.46
        static let G5: Float = 783.99
        static let A5: Float = 880.00
        static let C6: Float = 1046.50
    }

    private struct ToneSegment {
        let frequency: Float
        let duration: Float
        let isSquare: Bool
    }

    private override init() {
        super.init()
    }

    public func start() {
        setupAudioEngineIfNeeded()
    }

    private func setupAudioEngineIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        if isEngineSetup { return }

        audioEngine.attach(playerNode)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)

        do {
            try audioEngine.start()
            isEngineSetup = true
        } catch {
            print("[MioIslandSoundSynthesizer] Audio engine start failed: \(error)")
        }
    }

    public func play(event: String) {
        setupAudioEngineIfNeeded()

        let segments: [ToneSegment]
        switch event.lowercased() {
        case "start", "session_start":
            segments = [
                ToneSegment(frequency: Note.C5, duration: 0.08, isSquare: false),
                ToneSegment(frequency: Note.E5, duration: 0.08, isSquare: false)
            ]
        case "approval", "needs_approval":
            segments = [
                ToneSegment(frequency: Note.A5, duration: 0.07, isSquare: true),
                ToneSegment(frequency: Note.F5, duration: 0.07, isSquare: true),
                ToneSegment(frequency: Note.A5, duration: 0.09, isSquare: true)
            ]
        case "complete", "session_complete", "triumph":
            segments = [
                ToneSegment(frequency: Note.C5, duration: 0.07, isSquare: false),
                ToneSegment(frequency: Note.E5, duration: 0.07, isSquare: false),
                ToneSegment(frequency: Note.G5, duration: 0.07, isSquare: false),
                ToneSegment(frequency: Note.C6, duration: 0.12, isSquare: false)
            ]
        case "error", "alert":
            segments = [
                ToneSegment(frequency: Note.A3, duration: 0.18, isSquare: true)
            ]
        default:
            segments = [
                ToneSegment(frequency: Note.G4, duration: 0.06, isSquare: false)
            ]
        }

        guard let buffer = generatePCMBuffer(segments: segments, sampleRate: 44100, volume: 0.6) else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.audioEngine.isRunning {
                try? self.audioEngine.start()
            }
            if !self.playerNode.isPlaying {
                self.playerNode.play()
            }
            self.playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        }
    }

    private func generatePCMBuffer(segments: [ToneSegment], sampleRate: Double, volume: Float) -> AVAudioPCMBuffer? {
        let totalDuration = segments.reduce(Float(0)) { $0 + $1.duration }
        let frameCount = AVAudioFrameCount(Double(totalDuration) * sampleRate)
        guard frameCount > 0 else { return nil }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData?[0] else { return nil }

        var frameOffset = 0
        for seg in segments {
            let segFrames = Int(Double(seg.duration) * sampleRate)
            let amp = volume * 0.35
            let fadeFrames = min(Int(0.003 * sampleRate), segFrames / 4)

            for i in 0..<segFrames {
                let currentFrame = frameOffset + i
                if currentFrame >= Int(frameCount) { break }

                let phase = 2.0 * Float.pi * seg.frequency * Float(i) / Float(sampleRate)
                var sample: Float
                if seg.isSquare {
                    sample = sin(phase) >= 0 ? amp : -amp
                } else {
                    sample = sin(phase) * amp
                }

                // Envelope attack/release
                let env: Float
                if i < fadeFrames {
                    env = Float(i) / Float(fadeFrames)
                } else if i > segFrames - fadeFrames {
                    env = Float(segFrames - i) / Float(fadeFrames)
                } else {
                    env = 1.0
                }

                channelData[currentFrame] = sample * env
            }
            frameOffset += segFrames
        }

        return buffer
    }
}
