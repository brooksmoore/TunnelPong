import AVFoundation
import Foundation

/// Minimal cyberpunk / retrowave SFX + soft ambient pad.
/// Zero audio files — short procedural tones via AVAudioEngine.
final class Audio {
    static let shared = Audio()

    private let engine = AVAudioEngine()
    private let mainMixer: AVAudioMixerNode
    private var started = false
    private var ambientPlayer: AVAudioPlayerNode?
    private var ambientBuffer: AVAudioPCMBuffer?

    /// Every clip shares one format so a single pool of players can play all
    /// of them without reconnecting.
    private let sampleRate = 22_050.0
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: sampleRate,
                                            channels: 1)

    /// Waveforms are synthesised once and reused. Without this, every wall
    /// bounce rebuilt its buffer sample-by-sample on the main thread.
    private struct ToneKey: Hashable {
        let freq: Double
        let dur: Double
        let wave: Int
    }
    private var toneCache: [ToneKey: AVAudioPCMBuffer] = [:]

    /// Fixed pool of players attached once. Attaching and detaching nodes on a
    /// running engine per sound is expensive and can glitch the output, which
    /// matters here because rallies fire several sounds a second.
    private var pool: [AVAudioPlayerNode] = []
    private var poolCursor = 0
    private static let poolSize = 12

    private init() {
        mainMixer = engine.mainMixerNode
    }

    func prepare() {
        guard !started else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch { /* Catalyst may still play */ }

        mainMixer.outputVolume = 1
        ambientBuffer = makeDroneBuffer()

        if let format {
            for _ in 0..<Audio.poolSize {
                let player = AVAudioPlayerNode()
                engine.attach(player)
                engine.connect(player, to: mainMixer, format: format)
                pool.append(player)
            }
        }

        do {
            try engine.start()
            started = true
        } catch {
            started = false
        }
    }

    func setAmbient(_ on: Bool) {
        prepare()
        guard started else { return }
        if on {
            // Attach once; stop/play only. Attach/detach on a live engine was
            // the same cost class as the old one-shot leak.
            if ambientPlayer == nil, ambientBuffer != nil, let format {
                let player = AVAudioPlayerNode()
                engine.attach(player)
                engine.connect(player, to: mainMixer, format: format)
                ambientPlayer = player
            }
            guard let player = ambientPlayer, let buf = ambientBuffer else { return }
            player.volume = Config.audioAmbient * Config.audioMaster
            if !player.isPlaying {
                player.scheduleBuffer(buf, at: nil, options: .loops, completionHandler: nil)
                player.play()
            }
        } else {
            ambientPlayer?.stop()
            // Keep the node attached for the next title/play cycle.
        }
    }

    // MARK: - One-shots

    /// Player = higher “tick”; opponent = lower “tok” (rally call-and-response).
    func paddleHit(player: Bool) {
        if player {
            blip(freq: 990, dur: 0.04, wave: .square, vol: 0.32)
            blip(freq: 1480, dur: 0.025, wave: .sine, vol: 0.14, delay: 0.018)
        } else {
            blip(freq: 520, dur: 0.05, wave: .triangle, vol: 0.30)
            blip(freq: 390, dur: 0.04, wave: .sine, vol: 0.14, delay: 0.02)
        }
    }

    func wallBounce() {
        blip(freq: 220, dur: 0.05, wave: .triangle, vol: 0.28)
    }

    func pointScored() {
        blip(freq: 523, dur: 0.06, wave: .square, vol: 0.32)
        blip(freq: 784, dur: 0.09, wave: .square, vol: 0.28, delay: 0.05)
    }

    func lifeLost() {
        blip(freq: 180, dur: 0.12, wave: .saw, vol: 0.30)
        blip(freq: 120, dur: 0.16, wave: .triangle, vol: 0.22, delay: 0.04)
    }

    func levelUp() {
        blip(freq: 392, dur: 0.05, wave: .square, vol: 0.28)
        blip(freq: 523, dur: 0.05, wave: .square, vol: 0.28, delay: 0.06)
        blip(freq: 659, dur: 0.08, wave: .square, vol: 0.30, delay: 0.12)
    }

    func serve() {
        blip(freq: 660, dur: 0.04, wave: .sine, vol: 0.22)
    }

    func uiTap() {
        blip(freq: 990, dur: 0.03, wave: .sine, vol: 0.18)
    }

    // MARK: - Synthesis

    private enum Wave: Int { case sine, square, triangle, saw }

    private func blip(freq: Double, dur: Double, wave: Wave, vol: Float, delay: Double = 0) {
        prepare()
        guard started else { return }
        let work = {
            self.playTone(freq: freq, dur: dur, wave: wave,
                          vol: vol * Config.audioSFX * Config.audioMaster)
        }
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        } else {
            work()
        }
    }

    private func playTone(freq: Double, dur: Double, wave: Wave, vol: Float) {
        guard engine.isRunning, !pool.isEmpty else { return }
        let key = ToneKey(freq: freq, dur: dur, wave: wave.rawValue)
        let buffer: AVAudioPCMBuffer
        if let cached = toneCache[key] {
            buffer = cached
        } else {
            // Amplitude 1.0 in the buffer; loudness comes from player.volume,
            // so one cached waveform serves every volume it's played at.
            guard let made = makeToneBuffer(freq: freq, dur: dur, wave: wave) else { return }
            toneCache[key] = made
            buffer = made
        }
        // Round-robin, preferring an idle player so a busy one isn't cut off.
        var chosen: AVAudioPlayerNode?
        for i in 0..<pool.count {
            let candidate = pool[(poolCursor + i) % pool.count]
            if !candidate.isPlaying { chosen = candidate; poolCursor = (poolCursor + i + 1) % pool.count; break }
        }
        let player = chosen ?? pool[poolCursor]
        if chosen == nil { poolCursor = (poolCursor + 1) % pool.count }

        player.volume = max(0, min(1, vol))
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        player.play()
    }

    private func makeDroneBuffer() -> AVAudioPCMBuffer? {
        // ~2s seamless-ish pad loop (A1 + E2 soft sines).
        let sr = sampleRate
        let seconds = 2.0
        let n = Int(sr * seconds)
        guard let format,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n)),
              let data = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(n)
        let f1 = 55.0
        let f2 = 82.5
        let vol = 0.22
        for i in 0..<n {
            let t = Double(i) / sr
            // Fade ends slightly so loop click is mild.
            var env = 1.0
            let edge = 0.04
            if t < edge { env = t / edge }
            if t > seconds - edge { env = (seconds - t) / edge }
            let s = sin(2 * .pi * f1 * t) * 0.55
                + sin(2 * .pi * f2 * t) * 0.35
            data[i] = Float(s * vol * env)
        }
        return buffer
    }

    private func makeToneBuffer(freq: Double, dur: Double, wave: Wave) -> AVAudioPCMBuffer? {
        let sr = sampleRate
        let n = Int(dur * sr)
        guard n > 8,
              let format,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n)),
              let data = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(n)

        for i in 0..<n {
            let t = Double(i) / sr
            let phase = t * freq
            let frac = phase - floor(phase)
            let raw: Double
            switch wave {
            case .sine:     raw = sin(2 * .pi * phase)
            case .square:   raw = frac < 0.5 ? 1 : -1
            case .triangle: raw = 4 * abs(frac - 0.5) - 1
            case .saw:      raw = 2 * frac - 1
            }
            let attack = 0.004
            let relStart = dur * 0.45
            let env: Double
            if t < attack {
                env = t / attack
            } else if t > relStart {
                env = max(0, 1 - (t - relStart) / max(dur - relStart, 0.001))
            } else {
                env = 1
            }
            data[i] = Float(raw * env * 0.4)
        }
        return buffer
    }
}
