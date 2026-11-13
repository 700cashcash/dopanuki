import AVFoundation
import SwiftUI

/// しつもん・まねっこ用のマイク（録音は5秒まで。端末の外には送らない）
final class DogTalk: ObservableObject {
    @Published var listening = false
    @Published var level: CGFloat = 0       // 0〜1（マイクの音の大きさ）
    @Published var playLevel: CGFloat = 0   // 0〜1（まねっこ再生中の口の開き）
    @Published var playing = false
    @Published var micDenied = false

    private var recorder: AVAudioRecorder?
    private var meter: Timer?
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let pitch = AVAudioUnitTimePitch()
    private var engineReady = false
    private var url: URL { FileManager.default.temporaryDirectory.appendingPathComponent("dog-talk.m4a") }

    /// 押したとき：録音をはじめる（マイクが使えないときは、音なしで「きいてる」だけ）
    func begin() {
        listening = true
        level = 0
        let session = AVAudioSession.sharedInstance()
        session.requestRecordPermission { ok in
            DispatchQueue.main.async {
                self.micDenied = !ok
                guard ok, self.listening else { return }
                self.startRecorder()
            }
        }
    }

    private func startRecorder() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            ]
            let r = try AVAudioRecorder(url: url, settings: settings)
            r.isMeteringEnabled = true
            r.record(forDuration: 5)
            recorder = r
            meter = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self, let r = self.recorder else { return }
                r.updateMeters()
                let db = r.averagePower(forChannel: 0)            // -160〜0
                self.level = CGFloat(max(0, min(1, (db + 50) / 50)))
            }
        } catch {
            recorder = nil
        }
    }

    /// はなしたとき：録音をとめる。録れていたら true
    @discardableResult
    func end() -> Bool {
        listening = false
        meter?.invalidate()
        meter = nil
        level = 0
        guard let r = recorder else { return false }
        let had = r.currentTime > 0.3 || r.isRecording
        r.stop()
        recorder = nil
        return had
    }

    /// 高い声で まねっこ再生
    func playBack() {
        guard let file = try? AVAudioFile(forReading: url) else { return }
        do {
            if !engineReady {
                engine.attach(player)
                engine.attach(pitch)
                pitch.pitch = 700
                pitch.rate = 1.1
                engine.connect(player, to: pitch, format: file.processingFormat)
                engine.connect(pitch, to: engine.mainMixerNode, format: file.processingFormat)
                engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buf, _ in
                    guard let ch = buf.floatChannelData?[0] else { return }
                    let n = Int(buf.frameLength)
                    var sum: Float = 0
                    for i in 0..<n { sum += ch[i] * ch[i] }
                    let rms = n > 0 ? sqrt(sum / Float(n)) : 0
                    DispatchQueue.main.async { self?.playLevel = CGFloat(min(1, rms * 8)) }
                }
                engineReady = true
            }
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
            if !engine.isRunning { try engine.start() }
            playing = true
            player.scheduleFile(file, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    self?.playing = false
                    self?.playLevel = 0
                }
            }
            player.play()
        } catch {
            playing = false
        }
    }
}
