import SwiftUI

/// はじめて開いたときのオープニング（約20秒、右上でいつでもスキップ）
/// 1 宇宙の星のかたまり → 2 光る画面がせり上がる → 3 画面の滝に埋もれて灰色・読み込み中
/// → 4 画面が伏せられ、おなかの星がトクン → 5 光のほうへ這い出してポンッ → 6「…んま？」「ありがと」「いっしょに取り戻そ」
struct OpeningView: View {
    var onDone: () -> Void
    @State private var start = Date()
    @State private var hapticsDone: Set<Int> = []

    private let total: Double = 21

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { tl in
            let t = tl.date.timeIntervalSince(start)
            scene(t)
                .onChange(of: Int(t * 2)) { _ in haptics(t) }
        }
        .overlay(alignment: .topTrailing) {
            Button { Haptic.light(); onDone() } label: {
                Text("スキップ").font(.dp(13, .heavy)).foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 14).frame(height: 32)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }
            .padding(.trailing, 20).padding(.top, 8)
        }
        .preferredColorScheme(.dark)
        .onAppear { start = Date() }
    }

    // MARK: 場面

    @ViewBuilder
    private func scene(_ t: Double) -> some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                Color.black.ignoresSafeArea()
                stars(w: w, h: h, t: t)

                // 2〜4：光る縦長の画面
                if t > 3 && t < 13.5 {
                    screens(w: w, h: h, t: t)
                }

                // 1：星のかたまり → 3から犬に
                if t < 6.5 {
                    cluster(t: t)
                        .position(x: w / 2 + CGFloat(sin(t * 1.3)) * 10, y: h * 0.45 + CGFloat(cos(t)) * 8)
                        .opacity(t < 5.5 ? 1 : max(0, 6.5 - t))
                }
                if t >= 5.5 {
                    dog(t: t, w: w, h: h)
                }

                // 5：光のすきま
                if t > 12.5 && t < 17 {
                    Circle().fill(Color.white.opacity(0.85)).frame(width: 140, height: 140).blur(radius: 40)
                        .position(x: w * 0.78, y: h * 0.2)
                        .opacity(min(1, (t - 12.5) / 1.2) * (t > 16 ? max(0, 17 - t) : 1))
                }
                // 6：光の輪（抜け出した）
                if t > 16 {
                    Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 3)
                        .frame(width: 230, height: 230)
                        .scaleEffect(CGFloat(min(1.1, 0.6 + (t - 16) * 0.5)))
                        .opacity(max(0, 1 - (t - 16) / 3.5))
                        .position(x: w / 2, y: h * 0.47)
                }

                // 6：セリフ
                VStack(spacing: 10) {
                    if t > 17.2 { say("…んま？") }
                    if t > 18.4 { say("たすけてくれて、ありがと") }
                    if t > 19.6 { say("いっしょに取り戻そ") }
                }
                .position(x: w / 2, y: h * 0.18)
                .animation(.easeOut(duration: 0.3), value: Int(t * 2))

                if t > total - 0.6 {
                    VStack {
                        Spacer()
                        Button { Haptic.success(); onDone() } label: { Label("はじめる", systemImage: "hand.wave.fill") }
                            .buttonStyle(PuffyStyle(color: .blue, height: 58))
                            .padding(.horizontal, 24)
                            .padding(.bottom, 30)
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    private func say(_ s: String) -> some View {
        Text(s).font(.dp(16, .heavy)).foregroundColor(.black)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            .transition(.scale(scale: 0.7).combined(with: .opacity))
    }

    private func stars(w: CGFloat, h: CGFloat, t: Double) -> some View {
        ZStack {
            ForEach(0..<40, id: \.self) { i in
                Circle().fill(Color.white)
                    .frame(width: CGFloat(1 + i % 3), height: CGFloat(1 + i % 3))
                    .opacity(0.25 + 0.5 * abs(sin(t * 0.8 + Double(i))))
                    .position(x: w * CGFloat((i * 37) % 100) / 100, y: h * CGFloat((i * 61) % 100) / 100)
            }
        }
        .opacity(t > 6 && t < 13 ? 0.3 : 1)
    }

    /// 星のかたまり（ふわふわ）
    private func cluster(t: Double) -> some View {
        ZStack {
            ForEach(0..<9, id: \.self) { i in
                let a = Double(i) * 0.7 + t * 0.6
                Circle().fill([DP.yellow, Color.white, Color(hex: 0xBFE3FF)][i % 3])
                    .frame(width: CGFloat(6 + i % 4 * 3), height: CGFloat(6 + i % 4 * 3))
                    .offset(x: CGFloat(cos(a)) * CGFloat(14 + i * 3), y: CGFloat(sin(a * 1.2)) * CGFloat(10 + i * 2))
                    .blur(radius: 0.5)
            }
            Circle().fill(Color.white.opacity(0.25)).frame(width: 90, height: 90).blur(radius: 20)
        }
    }

    /// 光る縦長の画面が流れる（2：せり上がる、3：滝、4：伏せて止まる）
    private func screens(w: CGFloat, h: CGFloat, t: Double) -> some View {
        let speed: Double = t < 6 ? 120 : (t < 10 ? 520 : max(0, 520 - (t - 10) * 400))
        let flip = t > 10 ? min(1, (t - 10) / 1.5) : 0
        let flow = t < 6 ? (t - 3) * speed : 360 + (t - 6) * speed
        return ZStack {
            ForEach(0..<14, id: \.self) { i in
                let col = CGFloat(i % 3)
                let y = h + 120 - CGFloat((flow + Double(i) * 130).truncatingRemainder(dividingBy: Double(h) + 300))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [[DP.pink, DP.blue, DP.violet, DP.orange][i % 4], Color.white.opacity(0.9)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 70, height: 130)
                    .opacity(0.8)
                    .scaleEffect(x: 1, y: CGFloat(1 - flip * 0.92))
                    .position(x: w * (0.2 + 0.3 * col) + CGFloat(i % 2) * 10, y: y)
            }
        }
        .opacity(t < 3.6 ? (t - 3) / 0.6 : (t > 12.8 ? max(0, 13.5 - t) / 0.7 : 1))
    }

    /// 犬：3 灰色で読み込み中 → 4 おなかがトクン → 5 這い出してポン → 6 こっちを見る
    private func dog(t: Double, w: CGFloat, h: CGFloat) -> some View {
        let gray = t < 13
        let crawl = t > 13 ? min(1, (t - 13) / 2.8) : 0
        let pop = t > 15.8 && t < 16.4
        let glitchEye = t > 16.2 && t < 16.45
        let x = w / 2 + CGFloat(crawl) * (crawl < 1 ? w * 0.12 : 0)
        let y = h * 0.47 - CGFloat(crawl) * (crawl < 1 ? 50 : 0)
        return ZStack {
            if t > 11 && t < 13 {
                // おなかの奥で星がひとつ光る
                Circle().fill(DP.yellow).frame(width: 18, height: 18).blur(radius: 4)
                    .scaleEffect(CGFloat(1 + 0.6 * abs(sin((t - 11) * 4))))
                    .offset(y: 30)
            }
            DogView(size: 170, mood: t > 16.3 ? (t > 18.4 ? .happy : .normal) : (t < 11 ? .normal : .sleep), blinks: false,
                    pose: DogPose(headTilt: crawl > 0 && crawl < 1 ? -8 : 0, mouthOpen: t > 17.2 && t < 17.8 ? 0.6 : 0,
                                  squash: pop ? 0.4 : 0, paw: t > 19.6),
                    kimo: gray ? 3 : 0)
                .offset(x: glitchEye ? 3 : 0)
                .opacity(t < 6.5 ? (t - 5.5) : 1)
                .scaleEffect(pop ? 1.15 : 1)
        }
        .position(x: x, y: y)
    }

    /// トクン（4）、ポン（5）
    private func haptics(_ t: Double) {
        let marks: [(Int, Double)] = [(1, 11.2), (2, 11.8), (3, 16.0), (4, 17.2)]
        for (id, at) in marks where t >= at && !hapticsDone.contains(id) {
            hapticsDone.insert(id)
            if id <= 2 { Haptic.soft(1) } else if id == 3 { Haptic.rigid() } else { Haptic.light() }
        }
    }
}
