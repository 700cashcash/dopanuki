import AVFoundation

/// 音の種類（アップデートで ここに足していく。いまは1種を使う）
struct SoundPreset: Identifiable {
    struct Partial { let ratio: Double; let amp: Double; let decay: Double }
    let id: String
    let name: String
    let base: Double            // 基音（Hz）
    let partials: [Partial]     // 倍音（倍率・大きさ・余韻の秒数）。オクターブ・5度が中心
    let beatLeft: Double        // うなり（Hz、ゆっくり浅く）
    let beatRight: Double
    let attack: Double          // 立ち上がり（秒）
    let length: Double          // 1回の長さ（秒）
    let lowpass: Double         // キンキンを丸める（Hz）
    let level: Double           // 全体の大きさ
    let drone: [Double]         // うしろの和音（基音からの倍率。長調：1, 1.5, 2）
    let droneLevel: Double

    /// A：やわらか（F4・オクターブと5度だけ）
    static let soft = SoundPreset(
        id: "soft", name: "やわらか", base: 349.23,
        partials: [.init(ratio: 1, amp: 1, decay: 12), .init(ratio: 2, amp: 0.22, decay: 8), .init(ratio: 3, amp: 0.07, decay: 5)],
        beatLeft: 0.25, beatRight: 0.35, attack: 0.1, length: 15, lowpass: 3500, level: 0.17,
        drone: [1, 1.5, 2], droneLevel: 0.010)

    /// B：あかるい（A4・すこしきらきら）
    static let bright = SoundPreset(
        id: "bright", name: "あかるい", base: 440,
        partials: [.init(ratio: 1, amp: 1, decay: 11), .init(ratio: 2, amp: 0.28, decay: 8),
                   .init(ratio: 3, amp: 0.1, decay: 5), .init(ratio: 4, amp: 0.035, decay: 3)],
        beatLeft: 0.3, beatRight: 0.4, attack: 0.08, length: 14, lowpass: 4000, level: 0.15,
        drone: [1, 1.5, 2], droneLevel: 0.009)

    /// C：ふんわり（G4・いちばん丸く、ゆっくり）
    static let mellow = SoundPreset(
        id: "mellow", name: "ふんわり", base: 392,
        partials: [.init(ratio: 1, amp: 1, decay: 16), .init(ratio: 2, amp: 0.15, decay: 10), .init(ratio: 3, amp: 0.04, decay: 6)],
        beatLeft: 0.2, beatRight: 0.3, attack: 0.15, length: 16, lowpass: 3000, level: 0.16,
        drone: [1, 1.5, 2], droneLevel: 0.008)

    static let all: [SoundPreset] = [soft, bright, mellow]
    /// いま使う音（いちばん落ち着く「ふんわり」）
    static var current: SoundPreset { mellow }
}

/// 音の合成（音源ファイルは使わず、アプリの中で作る）
enum BowlSound {
    static let sampleRate: Double = 44_100

    /// 1回ぶん鳴らしたときの音（左右）。やわらかいアタック、長い余韻、ゆっくり浅い「うなり」、ローパス
    static func strike(_ preset: SoundPreset = .current) -> (left: [Float], right: [Float]) {
        let seconds = preset.length
        let n = Int(seconds * sampleRate)
        var l = [Float](repeating: 0, count: n), r = [Float](repeating: 0, count: n)
        let a = 1 - exp(-2 * .pi * preset.lowpass / sampleRate)   // ローパスの係数
        var fl = 0.0, fr = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let env = t < preset.attack ? 0.5 - 0.5 * cos(.pi * t / preset.attack) : 1
            let tail = min(1, (seconds - t) / 0.8)            // 最後はクリックしないように0へ
            var sl = 0.0, sr = 0.0
            for p in preset.partials {
                let f = preset.base * p.ratio
                let amp = p.amp * exp(-t / p.decay)
                // ほんの少しずらした2本：浅いうなり（ずらしは小さく、主音を強めに）
                sl += amp * (0.75 * sin(2 * .pi * f * t) + 0.25 * sin(2 * .pi * (f + preset.beatLeft) * t))
                sr += amp * (0.75 * sin(2 * .pi * f * t + 0.3) + 0.25 * sin(2 * .pi * (f + preset.beatRight) * t))
            }
            fl += a * (sl - fl)
            fr += a * (sr - fr)
            l[i] = Float(fl * env * tail * preset.level)
            r[i] = Float(fr * env * tail * preset.level)
        }
        return (l, r)
    }

    /// うしろで ずっと鳴る明るい和音（8秒でつなぎ目なしにループ）
    static func drone(_ preset: SoundPreset = .current, seconds: Double = 8) -> (left: [Float], right: [Float]) {
        let n = Int(seconds * sampleRate)
        var l = [Float](repeating: 0, count: n), r = [Float](repeating: 0, count: n)
        // 8秒でちょうど周期が合う周波数にそろえる
        let fs = preset.drone.map { (preset.base * $0 * seconds).rounded() / seconds }
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var sl = 0.0, sr = 0.0
            for (k, f) in fs.enumerated() {
                let w = k == 0 ? 1.0 : 0.6
                sl += w * sin(2 * .pi * f * t)
                sr += w * sin(2 * .pi * (f + 0.25) * t + Double(k))
            }
            l[i] = Float(sl * preset.droneLevel)
            r[i] = Float(sr * preset.droneLevel)
        }
        return (l, r)
    }
}

/// アプリ全体の音（ひとつのエンジンを共有）
/// ・ふだん：小さいドローン＋ときどき やさしく1回（.ambient：マナーモードでは鳴らない）
/// ・深呼吸中：音量を上げて、すうたびに1回（.playback：マナーモードでも鳴る）
final class BowlPlayer {
    static let shared = BowlPlayer()

    enum Mode { case off, ambient, breath }
    private(set) var mode: Mode = .off

    private let engine = AVAudioEngine()
    private var strikers: [AVAudioPlayerNode] = []
    private let droneNode = AVAudioPlayerNode()
    private var strikeBuffer: AVAudioPCMBuffer?
    private var droneBuffer: AVAudioPCMBuffer?
    private var next = 0
    private var ready = false
    private var ramps: [ObjectIdentifier: Timer] = [:]
    private var ambientTimer: Timer?

    // ふだんの音量（ドローン・ときどき鳴るボウル・全体）
    private let ambientDrone: Float = 0.35
    private let ambientStrike: Float = 0.3
    private let ambientMaster: Float = 0.55

    /// 深呼吸のスピーカー ON/OFF
    var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "p.bowlOn") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "p.bowlOn")
            if !newValue && mode == .breath { endBreath(strikeLast: false, fade: 0.5) }
        }
    }

    /// アプリ全体のBGM ON/OFF
    var bgmEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "p.bgmOn") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "p.bgmOn")
            if newValue { startAmbient() } else if mode == .ambient { stopAll(fade: 1) }
        }
    }

    private init() {
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] n in
            guard let self, let raw = n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended, self.mode != .off else { return }
            try? AVAudioSession.sharedInstance().setActive(true)
            if self.ready && !self.engine.isRunning { try? self.engine.start() }
        }
    }

    // MARK: しくみ

    private var preparing = false
    private var pending: [() -> Void] = []

    /// 音の合成は重いので、裏で作ってから鳴らす（画面を止めない）
    private func whenReady(_ then: @escaping () -> Void) {
        if ready { then(); return }
        pending.append(then)
        guard !preparing else { return }
        preparing = true
        let preset = SoundPreset.current
        DispatchQueue.global(qos: .userInitiated).async {
            let strike = BowlSound.strike(preset)
            let drone = BowlSound.drone(preset)
            DispatchQueue.main.async {
                guard let fmt = AVAudioFormat(standardFormatWithSampleRate: BowlSound.sampleRate, channels: 2) else { return }
                self.strikeBuffer = Self.buffer(strike, fmt)
                self.droneBuffer = Self.buffer(drone, fmt)
                self.attachNodes(fmt)
                self.ready = true
                self.preparing = false
                let jobs = self.pending
                self.pending = []
                jobs.forEach { $0() }
            }
        }
    }

    private let bus = AVAudioMixerNode()
    private let reverb = AVAudioUnitReverb()

    /// ボウルとドローン → まとめて → 響き（リバーブ）→ 出力
    private func attachNodes(_ fmt: AVAudioFormat) {
        engine.attach(bus)
        engine.attach(reverb)
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 35
        engine.connect(bus, to: reverb, format: fmt)
        engine.connect(reverb, to: engine.mainMixerNode, format: fmt)
        for _ in 0..<4 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: bus, format: fmt)
            strikers.append(p)
        }
        engine.attach(droneNode)
        engine.connect(droneNode, to: bus, format: fmt)
    }

    private static func buffer(_ s: (left: [Float], right: [Float]), _ fmt: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let b = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(s.left.count)),
              let ch = b.floatChannelData else { return nil }
        b.frameLength = AVAudioFrameCount(s.left.count)
        s.left.withUnsafeBufferPointer { ch[0].update(from: $0.baseAddress!, count: s.left.count) }
        s.right.withUnsafeBufferPointer { ch[1].update(from: $0.baseAddress!, count: s.right.count) }
        return b
    }

    private func run(_ category: AVAudioSession.Category) -> Bool {
        guard ready else { return false }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(category, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            if !engine.isRunning { try engine.start() }
            return true
        } catch {
            return false
        }
    }

    private func startDrone(volume: Float, over seconds: Double) {
        guard let d = droneBuffer else { return }
        if !droneNode.isPlaying {
            droneNode.volume = 0
            droneNode.scheduleBuffer(d, at: nil, options: .loops)
            droneNode.play()
        }
        ramp(droneNode, to: volume, seconds: seconds)
    }

    private func strikeNow(volume: Float) {
        guard let b = strikeBuffer else { return }
        let p = strikers[next % strikers.count]
        next += 1
        p.stop()
        p.volume = volume
        p.scheduleBuffer(b, at: nil)
        p.play()
    }

    // MARK: ふだん（BGM）

    /// 部屋などにいるとき：小さいドローン＋ときどき1回
    func startAmbient() {
        guard bgmEnabled, mode != .breath else { return }
        whenReady { [weak self] in self?.startAmbientNow() }
    }

    private func startAmbientNow() {
        guard bgmEnabled, mode != .breath, run(.ambient) else { return }
        mode = .ambient
        ramp(engine.mainMixerNode, to: ambientMaster, seconds: 2)
        startDrone(volume: ambientDrone, over: 4)
        scheduleAmbientStrike(first: true)
    }

    private func scheduleAmbientStrike(first: Bool = false) {
        ambientTimer?.invalidate()
        ambientTimer = Timer.scheduledTimer(withTimeInterval: first ? 3 : Double.random(in: 20...40), repeats: false) { [weak self] _ in
            guard let self, self.mode == .ambient else { return }
            self.strikeNow(volume: self.ambientStrike)
            self.scheduleAmbientStrike()
        }
    }

    /// バックグラウンド・おやすみロック中：フェードアウトして止める
    func stopAll(fade: Double = 1) {
        ambientTimer?.invalidate()
        mode = .off
        guard ready else { return }
        ramp(engine.mainMixerNode, to: 0, seconds: fade) { [weak self] in
            guard let self, self.mode == .off else { return }
            self.strikers.forEach { $0.stop() }
            self.droneNode.stop()
            self.engine.pause()
        }
    }

    // MARK: 深呼吸

    /// 呼吸をはじめる：2〜3秒で音量を上げて、ボウル1回
    func begin() {
        guard enabled else { return }
        mode = .breath
        whenReady { [weak self] in self?.beginNow() }
    }

    private func beginNow() {
        guard mode == .breath, enabled, run(.playback) else { return }
        ambientTimer?.invalidate()
        mode = .breath
        ramp(engine.mainMixerNode, to: 1, seconds: 2.5)
        startDrone(volume: 1, over: 3)
        strikeNow(volume: 0.8)
    }

    /// すうはじめに やさしく1回（余韻が重なる）
    func strike(volume: Float = 0.8) {
        guard mode == .breath else { return }
        strikeNow(volume: volume)
    }

    /// 最後まで できた：もう1回鳴らして、ふだんの音へ
    func finish() { endBreath(strikeLast: true, fade: 3) }

    /// 止めた：すぐ（1秒で）ふだんの音へ
    func stop(fade: Double = 1) { endBreath(strikeLast: false, fade: fade) }

    private func endBreath(strikeLast: Bool, fade: Double) {
        guard mode == .breath else { return }
        if strikeLast { strikeNow(volume: 1) } else { strikers.forEach { ramp($0, to: 0, seconds: fade) } }
        if bgmEnabled {
            mode = .ambient
            ramp(engine.mainMixerNode, to: ambientMaster, seconds: fade)
            ramp(droneNode, to: ambientDrone, seconds: fade) { [weak self] in
                guard let self, self.mode == .ambient else { return }
                try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                self.scheduleAmbientStrike()
            }
        } else {
            stopAll(fade: strikeLast ? 4 : fade)
        }
    }

    // MARK: なめらかに音量をかえる

    private func ramp(_ node: AnyObject, to target: Float, seconds: Double, done: (() -> Void)? = nil) {
        let key = ObjectIdentifier(node)
        ramps[key]?.invalidate()
        let getVol: () -> Float
        let setVol: (Float) -> Void
        if let p = node as? AVAudioPlayerNode {
            getVol = { p.volume }; setVol = { p.volume = $0 }
        } else if let m = node as? AVAudioMixerNode {
            getVol = { m.outputVolume }; setVol = { m.outputVolume = $0 }
        } else { return }
        let start = getVol()
        let steps = max(1, Int(seconds / 0.05))
        var k = 0
        ramps[key] = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] t in
            k += 1
            let x = Float(k) / Float(steps)
            setVol(start + (target - start) * x)
            if k >= steps {
                t.invalidate()
                self?.ramps[key] = nil
                done?()
            }
        }
    }
}
