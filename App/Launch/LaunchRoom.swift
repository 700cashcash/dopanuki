import SwiftUI

/// 部屋：ドパ抜きちゃん＋まん中に「時間を取り戻す」。きょうの目標・取り戻した時間・時計連動の部屋の色
struct LaunchRoomView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var life: LifeState
    @State private var showSettings = false
    @State private var line: String?
    @State private var squish = false
    @State private var hearts: [UUID] = []
    @State private var strokeDist: CGFloat = 0
    @State private var lastDrag: CGPoint?
    @State private var yofukashi = false
    @State private var quizAnswer: Int?
    @State private var lineToken = 0

    private var hour: Int {
        #if DEBUG
        if UserDefaults.standard.object(forKey: "debugHour") != nil { return UserDefaults.standard.integer(forKey: "debugHour") }
        #endif
        return Calendar.current.component(.hour, from: game.clock)
    }
    /// おやすみロック中（基地につないで ねてる）
    private var locked: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debugLocked") { return true }
        #endif
        return NightLock.isSleepTime(game.clock) && game.nightBaseKey == NightLock.nightKey(game.clock)
    }
    private var tint: Color {
        if locked { return Color(hex: 0x0C0E24) }
        switch hour {
        case 5..<10: return DP.orange
        case 10..<16: return DP.blue
        case 16..<19: return DP.pink
        default: return DP.purple
        }
    }
    private var isNight: Bool { hour >= 19 || hour < 5 }

    var body: some View {
        VStack(spacing: 16) {
            topBar
            room
            Button { game.flow = .pick } label: { Label("時間を取り戻す", systemImage: "play.fill") }
                .buttonStyle(PuffyStyle(color: .blue, height: 66))
                .disabled(locked)
                .opacity(locked ? 0.4 : 1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .background(TopGlow(color: tint.opacity(locked ? 0.2 : 0.55), reach: 0.45))
        .sheet(isPresented: $showSettings) { LaunchSettingsView().environmentObject(game).environmentObject(life) }
        .onAppear {
            arrive()
            #if DEBUG
            let d = UserDefaults.standard
            if d.bool(forKey: "debugSettings") { showSettings = true }
            switch d.string(forKey: "debugNeenee") {
            case "morning": life.neenee = .morning
            case "plan": life.neenee = .yesterdayPlan("英単語")
            case "quiz": life.neenee = .quiz(Quiz.all[2])
            default: break
            }
            if let s = d.string(forKey: "debugLine") { line = s }
            #endif
        }
    }

    // MARK: 上：きょうの目標・取り戻した時間・歯車

    private var topBar: some View {
        HStack(spacing: 8) {
            pill(icon: "flag.fill", color: DP.yellow, text: life.todayGoal.isEmpty ? "きょう: まだ" : "きょう: \(life.todayGoal)")
            pill(icon: "clock.arrow.circlepath", color: DP.green, text: hm(life.todayMinutes))
            Spacer()
            Button { showSettings = true } label: { CircleIcon(system: "gearshape") }
                .buttonStyle(PressStyle())
                .accessibilityLabel(Text("設定"))
        }
    }

    private func pill(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundColor(color)
            Text(text).font(.dp(13, .heavy)).lineLimit(1)
        }
        .padding(.horizontal, 11).frame(height: 32)
        .background(Capsule().fill(Color.white.opacity(0.08)))
    }

    private func hm(_ m: Int) -> String { m >= 60 ? "\(m / 60)時間\(m % 60)分" : "\(m)分" }

    // MARK: 部屋

    private var room: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(colors: [tint.opacity(locked ? 1 : 0.9), tint.opacity(0.35), DP.card],
                                         startPoint: .top, endPoint: .bottom))
                // 窓
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isNight || locked ? Color(hex: 0x10163A) : Color(hex: 0xBFE3FF))
                    .overlay(Circle().fill(isNight || locked ? DP.yellow : .white).frame(width: 18, height: 18).offset(x: 16, y: -14))
                    .overlay(Rectangle().fill(Color.white.opacity(0.4)).frame(width: 3))
                    .overlay(Rectangle().fill(Color.white.opacity(0.4)).frame(height: 3))
                    .frame(width: 90, height: 78)
                    .position(x: 70, y: 70)
                // 夜のランプ
                if isNight && !locked {
                    Circle().fill(DP.yellow.opacity(0.35)).frame(width: 120, height: 120).blur(radius: 24)
                        .position(x: geo.size.width - 60, y: 130)
                    Capsule().fill(DP.yellow).frame(width: 30, height: 20).position(x: geo.size.width - 60, y: 130)
                    Rectangle().fill(Color(hex: 0x6A5A4A)).frame(width: 3, height: 70).position(x: geo.size.width - 60, y: 175)
                }
                // 床・ベッド
                Ellipse().fill(Color.black.opacity(0.25)).frame(width: 260, height: 64).position(x: cx, y: geo.size.height - 70)
                Ellipse().fill((locked ? DP.violet : DP.pink).opacity(0.5)).frame(width: 200, height: 46).position(x: cx, y: geo.size.height - 70)

                // ドパ抜きちゃん
                DogView(size: 190, mood: locked ? .sleep : (squish || (line != nil && life.kimo == 0) ? .happy : .normal),
                        pose: DogPose(squash: squish ? 0.7 : 0), kimo: locked ? 0 : life.kimo, alive: !locked)
                    .bob(locked ? 2 : 4, period: locked ? 3.4 : 2.8)
                    .contentShape(Rectangle())
                    .gesture(petGesture)
                    .position(x: cx, y: geo.size.height - 150)
                    .accessibilityLabel(Text(game.dogName + "。なでてね"))

                ForEach(hearts, id: \.self) { id in
                    RoomHeart { hearts.removeAll { $0 == id } }
                        .position(x: cx, y: geo.size.height - 230)
                }

                // よふかしさん（2〜4時、まれ）
                if yofukashi {
                    YofukashiSan()
                        .position(x: cx + 110, y: geo.size.height - 90)
                        .transition(.opacity)
                }

                // 吹き出し・ねえねえ
                VStack {
                    if let n = life.neenee, !locked {
                        neeneeCard(n).transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
                    } else if let l = line {
                        Bubble(text: glitched(l)).transition(.scale(scale: 0.7).combined(with: .opacity))
                    }
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.horizontal, 14)
            }
        }
        .frame(height: 440)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: line)
        .animation(.easeInOut(duration: 0.6), value: locked)
    }

    /// キモさ4の日は、吹き出しの文字がバグる
    private func glitched(_ s: String) -> String {
        guard life.kimo >= 4, !locked else { return s }
        return String(s.enumerated().map { i, c in i % 4 == 2 ? "▯" : c })
    }

    // MARK: 開いたとき

    private func arrive() {
        if locked {
            say(["…いいね…ちがう…それじゃない…", "…むにゃ…あと5ふん…", "…おなかの…ほし…"].randomElement()!, for: 4)
            let h = Calendar.current.component(.hour, from: Date())
            #if DEBUG
            let forceYofu = UserDefaults.standard.bool(forKey: "debugYofukashi")
            #else
            let forceYofu = false
            #endif
            if forceYofu || ((2..<4).contains(h) && Int.random(in: 0..<3) == 0) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeIn(duration: 0.8)) { yofukashi = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { withAnimation(.easeOut(duration: 1)) { yofukashi = false } }
                }
            }
            return
        }
        if let g = life.morningGreeting() {
            say(g.text, for: 3.5)
            if g.back { celebrate() } else if life.kimo == 0 { Haptic.light() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) { life.pickNeenee() }
        } else {
            life.pickNeenee()
        }
    }

    private func say(_ s: String, for seconds: Double = 2.4) {
        lineToken += 1
        let tok = lineToken
        line = s
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { if tok == lineToken { line = nil } }
    }

    private func celebrate() {
        Haptic.success()
        for i in 0..<8 { DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) { hearts.append(UUID()) } }
        squish = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { squish = false } }
    }

    // MARK: なでる（むにっ）

    private var petGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if let l = lastDrag { strokeDist += hypot(v.location.x - l.x, v.location.y - l.y) }
                lastDrag = v.location
                if strokeDist > 70 { strokeDist = 0; pet() }
            }
            .onEnded { v in
                if hypot(v.translation.width, v.translation.height) < 8 { pet() }
                lastDrag = nil; strokeDist = 0
            }
    }

    private func pet() {
        guard !locked else { say("…んぅ…", for: 1.5); return }
        Haptic.soft()
        hearts.append(UUID())
        withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) { squish = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.35)) { squish = false }
        }
        if life.neenee == nil { say(["んま！", "ぷぁ", "むにっ", "えへへ〜", "もっと〜"].randomElement()!) }
    }

    // MARK: ねえねえ

    @ViewBuilder private func neeneeCard(_ n: Neenee) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(neeneeTitle(n)).font(.dp(15, .heavy)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                Button { life.closeNeenee(); quizAnswer = nil } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .heavy)).foregroundColor(DP.gray)
                        .frame(width: 28, height: 28).background(Circle().fill(Color.white.opacity(0.1)))
                }
                .accessibilityLabel(Text("とじる"))
            }
            switch n {
            case .morning:
                FlowChips(items: Array(life.purposes.prefix(6)), selected: "") { p in
                    life.setTodayGoal(p); life.closeNeenee(); Haptic.success(); say("いいね！ \(p)、おうえんしてる")
                }
            case .yesterdayPlan(let p):
                HStack(spacing: 8) {
                    Button("やる") { life.setTodayGoal(p); life.closeNeenee(); Haptic.success(); say("やった！ いっしょにがんばろ") }
                        .buttonStyle(PuffyStyle(color: .blue, height: 38, fullWidth: false))
                    Button("ちがうのにする") { life.neenee = .morning }
                        .buttonStyle(PuffyStyle(color: .white, height: 38, fullWidth: false, strong: false))
                }
            case .quiz(let q):
                HStack(spacing: 8) {
                    Image(systemName: q.icon).font(.system(size: 26, weight: .bold)).foregroundColor(DP.yellow)
                        .frame(width: 44, height: 44).background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(q.choices.indices, id: \.self) { i in
                            Button {
                                quizAnswer = i
                                i == q.answer ? Haptic.success() : Haptic.soft(0.6)
                            } label: {
                                Text(q.choices[i]).font(.dp(13, .heavy))
                                    .foregroundColor(quizAnswer == i ? .black : .white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12).frame(height: 32)
                                    .background(Capsule().fill(quizAnswer == nil ? Color.white.opacity(0.1)
                                                               : (i == q.answer ? DP.green : (quizAnswer == i ? DP.yellow : Color.white.opacity(0.06)))))
                            }
                            .disabled(quizAnswer != nil)
                        }
                    }
                }
                if let a = quizAnswer {
                    Text((a == q.answer ? "せいかい！ " : "おしい！ ") + q.why).font(.dp(12, .bold)).foregroundColor(DP.yellow)
                        .fixedSize(horizontal: false, vertical: true)
                }
            case .aside:
                EmptyView()
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.black.opacity(0.72)))
    }

    private func neeneeTitle(_ n: Neenee) -> String {
        switch n {
        case .morning: return "ねえねえ、きょう何するの？"
        case .yesterdayPlan(let p): return "きのう言ってた「\(p)」、やる？"
        case .quiz(let q): return "これ知ってる？\n" + q.question
        case .aside(let s): return s
        }
    }
}

private struct RoomHeart: View {
    let done: () -> Void
    @State private var up = false
    private let dx = CGFloat.random(in: -50...50)
    var body: some View {
        Image(systemName: "heart.fill").font(.system(size: 22)).foregroundColor(DP.pink)
            .offset(x: up ? dx : 0, y: up ? -90 : 0)
            .opacity(up ? 0 : 1)
            .scaleEffect(up ? 1.3 : 0.6)
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) { up = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { done() }
            }
            .allowsHitTesting(false)
    }
}

/// 夜中に枕もとに出る、なぞの生きもの
struct YofukashiSan: View {
    @State private var bob = false
    var body: some View {
        VStack(spacing: 6) {
            Text("…ねなよ").font(.dp(12, .heavy)).foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.6)))
            ZStack {
                Ellipse().fill(Color(hex: 0x2B2F5C)).frame(width: 46, height: 52)
                Ellipse().fill(Color(hex: 0x3B4078)).frame(width: 34, height: 18).offset(y: -18)
                HStack(spacing: 10) {
                    Circle().fill(DP.yellow).frame(width: 7, height: 7)
                    Circle().fill(DP.yellow).frame(width: 7, height: 7)
                }
                .offset(y: -4)
            }
            .offset(y: bob ? -3 : 3)
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.2).repeatForever()) { bob = true } }
        .accessibilityLabel(Text("よふかしさん：ねなよ"))
    }
}
