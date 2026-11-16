import SwiftUI

/// おかえりリアクション（わくわく 0.5秒 → むぎゅっ 0.5秒 → ごほうび顔）→ 結果カード
struct WelcomeBackView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var life: LifeState
    let result: SessionResult

    @State private var phase = 0          // 0 わくわく, 1 むぎゅっ, 2 ごほうび顔, 3 結果カード
    @State private var pose = DogPose(teary: true)
    @State private var jump: CGFloat = 0
    @State private var line = ""
    @State private var praise = ""
    @State private var hearts: [UUID] = []

    private var sad: Bool { !result.completed && result.minutes < max(1, result.goal) }
    /// おやすみ時間（夜のロック中・消灯中）のおかえりは、ねむそう版
    private var sleepy: Bool {
        let key = NightLock.nightKey()
        return NightLock.isSleepTime() && (game.nightBaseKey == key || life.data.sleepKey == key)
    }

    var body: some View {
        ZStack {
            TopGlow(color: sad ? Color(hex: 0x3B2FA0) : Color(hex: 0x1E9E5E), reach: 0.6)
            if phase >= 2 && !sad && !sleepy { Confetti().ignoresSafeArea() }
            if phase < 3 { reaction } else { resultCard.transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: phase)
        .onAppear {
            play()
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "debugWelcomeCard") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { phase = 3 }
            }
            #endif
        }
    }

    // MARK: リアクション

    private var reaction: some View {
        VStack(spacing: 20) {
            Spacer()
            if phase >= 2 {
                VStack(spacing: 8) {
                    Bubble(text: line)
                    if !praise.isEmpty {
                        Text(praise).font(.dp(18, .heavy)).foregroundColor(DP.yellow)
                    }
                }
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else {
                Color.clear.frame(height: 70)
            }
            ZStack {
                ForEach(hearts, id: \.self) { id in
                    WelcomeHeart { hearts.removeAll { $0 == id } }
                }
                DogView(size: 230, mood: phase >= 2 ? (sad ? .normal : .happy) : .normal, blinks: phase < 2,
                        pose: pose, kimo: life.kimo, alive: true)
                    .offset(y: -jump)
            }
            .frame(height: 260)
            Text(result.minutes > 0 ? "\(result.minutes)分 取り戻した" : "おかえり").font(.dp(15, .heavy)).foregroundColor(.white.opacity(0.8))
                .opacity(phase >= 2 ? 1 : 0)
            Spacer()
            Button { withAnimation { phase = 3 } } label: { Text("つぎへ") }
                .buttonStyle(PuffyStyle(color: .white, height: 52, strong: false))
                .opacity(phase >= 2 ? 1 : 0)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
        .contentShape(Rectangle())
        .onTapGesture { if phase >= 2 { withAnimation { phase = 3 } } }
    }

    /// 3拍子
    private func play() {
        life.record(result)
        if sad {
            pose = DogPose(headTilt: -8, eyes: .normal)
            phase = 2
            line = "またいっしょにやろ" + (sleepy ? "…じゃ、ねよ" : "")
            praise = result.minutes > 0 ? "\(result.minutes)分でも、えらいよ" : ""
            Haptic.soft(0.5)
            return
        }
        // わくわく：目うるうる・しっぽぶんぶん
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) { pose.tailWag = i % 2 == 0 ? 26 : -18 }
            }
        }
        // むぎゅっ：飛びついて、体ごとつぶれて戻る
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.15)) { jump = sleepy ? 14 : 40 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                Haptic.medium()
                withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) { jump = 0; pose.squash = sleepy ? 0.4 : 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { pose.squash = 0 }
                }
            }
        }
        // ごほうび顔：こっちを見て「ありがと」
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Haptic.success()
            line = Self.line(for: result.minutes) + (sleepy ? "…じゃ、ねよ" : "")
            praise = Self.praise(purpose: result.purpose, minutes: result.minutes)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                phase = 2
                pose = sleepy ? DogPose(tailWag: 4, mouthOpen: 0.3, eyes: .sleep, paw: true)
                              : DogPose(tailWag: 10, mouthOpen: 0.5, paw: true)
            }
            for i in 0..<6 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) { hearts.append(UUID()) }
            }
        }
    }

    /// 置いた時間の段階で、ランダムに
    static func line(for m: Int) -> String {
        let tiers: [(Int, [String])] = [
            (480, ["スマホ生きてる？", "もはや修行", "ぼく、信じてたよ"]),
            (240, ["人間やめた？", "おなかの宇宙が広がった", "…まぶしい"]),
            (120, ["ありえん…", "伝説じゃん", "一生ついてく"]),
            (60, ["1時間だよ!?", "えぐい", "ぼく泣きそう"]),
            (45, ["すごすぎ", "天才？", "ほんとにやったの？"]),
            (25, ["集中できたね", "かっこいい", "えらすぎ"]),
            (10, ["いいかんじ", "その調子", "ぷぁ！"]),
            (0, ["えらっ", "やるじゃん", "んま！"]),
        ]
        return tiers.first { m >= $0.0 }!.1.randomElement()!
    }

    /// 中身ごとほめる
    static func praise(purpose: String, minutes: Int) -> String {
        guard !purpose.isEmpty else { return "" }
        if purpose == "はじめての3分" { return "はじめての3分、できたじゃん！" }
        let t = minutes >= 60 ? "\(minutes / 60)時間" + (minutes % 60 > 0 ? "\(minutes % 60)分" : "") : "\(minutes)分"
        return "\(purpose)\(t)やったじゃん！"
    }

    // MARK: 結果カード

    private var resultCard: some View {
        let card = SavedCard(kind: .result, minutes: result.minutes, purpose: result.purpose)
        let img = renderCard(ShareCard(card: card, name: life.nameForCards(game)))
        return VStack(spacing: 16) {
            HStack {
                Text(sad ? "ここまで" : "おかえり！").font(.dp(26, .heavy))
                Spacer()
                Button { game.closeResult() } label: { CircleIcon(system: "xmark") }.buttonStyle(PressStyle())
            }
            ShareCard(card: card, name: life.nameForCards(game))
                .scaleEffect(0.82)
                .frame(height: 440)
            Text("記録に保存したよ").font(.dp(12, .bold)).foregroundColor(DP.gray)
            ShareLink(item: img, message: Text("#ドパ抜きチャレンジ"), preview: SharePreview("ドパ抜き", image: img)) {
                Label("シェアする", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PuffyStyle(color: .blue, height: 56))
            Button("とじる") { game.closeResult() }
                .buttonStyle(PuffyStyle(color: .white, height: 50, strong: false))
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

private struct WelcomeHeart: View {
    let done: () -> Void
    @State private var up = false
    private let dx = CGFloat.random(in: -90...90)
    var body: some View {
        Image(systemName: "heart.fill").font(.system(size: 26)).foregroundColor(DP.pink)
            .offset(x: up ? dx : 0, y: up ? -170 : -40)
            .opacity(up ? 0 : 1)
            .scaleEffect(up ? 1.4 : 0.6)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1)) { up = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { done() }
            }
            .allowsHitTesting(false)
    }
}

extension LifeState {
    /// カードに出す自分の名前（宣言カードの「○○は」）
    func nameForCards(_ game: GameState) -> String {
        let n = game.userName.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "わたし" : n
    }
}
