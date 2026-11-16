import SwiftUI

/// 深呼吸（まんなかのタブ）。4秒すって、4秒はく。振動でリズムをおしえる
struct BreathView: View {
    var compact = false
    @EnvironmentObject private var game: GameState
    @Environment(\.dismiss) private var dismiss

    @State private var lengthIndex = 0
    @State private var startedAt: Date?
    @State private var finished = false
    @State private var lastHapticStep = -1
    @State private var page = 0
    @State private var showRoad = false
    @State private var unlocked: [RoadReward] = []

    private let lengths = [1, 3, 5, 10]
    private let cycle: Double = 8
    private let ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private var total: Double { Double(lengths[lengthIndex] * 60) }

    var body: some View {
        ZStack {
            scenery
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: startedAt == nil)) { tl in
                stage(now: tl.date)
            }
        }
        .overlay { if !unlocked.isEmpty { unlockCelebration } }
        .preferredColorScheme(.dark)
        .onReceive(ticker) { now in tick(now) }
        .sheet(isPresented: $showRoad) { RoadView().environmentObject(game) }
        #if DEBUG
        .onAppear { if UserDefaults.standard.bool(forKey: "debugRoad") { game.breathMinutes = max(game.breathMinutes, 16); showRoad = true } }
        #endif
    }

    /// 深呼吸がおわった／止めたとき：分数をたして、ひらいた ごほうび をおいわい
    private func record(_ seconds: Double) {
        let got = game.addBreath(seconds: seconds)
        if !got.isEmpty {
            Haptic.success()
            if !AppMode.launch { withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { unlocked = got } }
        }
    }

    private var unlockCelebration: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            Confetti().ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: unlocked.last!.icon).font(.system(size: 54, weight: .bold)).foregroundColor(DP.yellow)
                ForEach(unlocked) { r in Text(r.getText).font(.dp(24, .black)) }
                DogView(size: 110, mood: .happy).bob(8, period: 0.9)
                Button("やったー！") { withAnimation { unlocked = [] } }
                    .buttonStyle(PuffyStyle(color: .yellow, height: 54))
                    .padding(.horizontal, 40)
            }
            .transition(.scale(scale: 0.7).combined(with: .opacity))
        }
    }

    /// ごほうびの道への入口（つぎまで あと何分）
    private var roadPill: some View {
        Button { showRoad = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "map.fill").font(.system(size: 12, weight: .bold)).foregroundColor(DP.yellow)
                VStack(alignment: .leading, spacing: 4) {
                    if let n = Road.next(after: game.breathMinutes) {
                        Text("\(n.name)まで あと\(n.minutes - game.breathMinutes)分").font(.dp(12, .heavy))
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.25))
                                Capsule().fill(DP.yellow)
                                    .frame(width: g.size.width * CGFloat(10 - (n.minutes - game.breathMinutes)) / 10)
                            }
                        }
                        .frame(width: 110, height: 4)
                    } else {
                        Text("ごほうびの道 ぜんぶクリア！").font(.dp(12, .heavy))
                    }
                }
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .heavy)).foregroundColor(.white.opacity(0.6))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12).frame(height: 40)
            .background(Capsule().fill(Color.black.opacity(0.45)))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(Text("ごほうびの道"))
    }

    /// 音（BGM）。音源はまだないので名前だけ
    private var soundChips: some View {
        VStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Image(systemName: "music.note").font(.system(size: 13, weight: .bold)).foregroundColor(.white.opacity(0.7))
                    ForEach(Road.sounds(breathMinutes: game.breathMinutes), id: \.id) { snd in
                        Button { Haptic.select(); game.bgm = snd.id } label: { Chip(label: snd.name, on: game.bgm == snd.id) }
                            .buttonStyle(PressStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
            if game.bgm != "none" {
                Text("音はもうすぐ").font(.dp(10, .bold)).foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private var owned: [NatureScene] { Scenes.owned(breathMinutes: game.breathMinutes) }
    private var current: NatureScene? { page < owned.count ? owned[page] : nil }

    /// 景色（左右スワイプで切りかえ。さいごはガチャへの案内）
    private var scenery: some View {
        ZStack {
            DP.bg
            TabView(selection: $page) {
                ForEach(Array(owned.enumerated()), id: \.element.id) { i, sc in
                    SceneBackdrop(scene: sc).tag(i)
                }
                lockedCard.tag(owned.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: page) { _ in Haptic.select() }
            LinearGradient(colors: [Color.black.opacity(0.55), Color.black.opacity(0.15), Color.black.opacity(0.7)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    private var lockedCard: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1A1A1A), Color(hex: 0x2A2A2A)], startPoint: .top, endPoint: .bottom)
            Ellipse().fill(Color.white.opacity(0.06)).frame(width: 600, height: 300).offset(x: -80, y: 330)
            Ellipse().fill(Color.white.opacity(0.09)).frame(width: 520, height: 260).offset(x: 140, y: 380)
        }
    }

    private var sceneLabel: some View {
        HStack(spacing: 6) {
            if let sc = current {
                Image(systemName: "photo").font(.system(size: 11, weight: .bold))
                Text(sc.name).font(.dp(12, .heavy))
                Text("\(page + 1)/\(owned.count)").font(.num(11)).foregroundColor(.white.opacity(0.7))
            } else {
                Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold))
                Text("深呼吸で 景色がふえるよ").font(.dp(12, .heavy))
                Text("あと\(Scenes.all.count - owned.count)こ")
                    .font(.dp(11, .bold)).foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 12).frame(height: 30)
        .background(Capsule().fill(Color.black.opacity(0.4)))
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func stage(now: Date) -> some View {
        let t = startedAt.map { now.timeIntervalSince($0) } ?? 0
        let inCycle = t.truncatingRemainder(dividingBy: cycle)
        let inhale = inCycle < cycle / 2
        // 0.78 → 1 → 0.78（なめらか）
        let wave = startedAt == nil ? 0.5 : (1 - cos(inCycle / cycle * 2 * .pi)) / 2
        let scale = 0.78 + 0.22 * wave
        let remain = max(0, total - t)

        VStack(spacing: 0) {
            HStack {
                if compact {
                    Button { dismiss() } label: { CircleIcon(system: "xmark") }.buttonStyle(PressStyle())
                }
                Spacer()
            }
            .frame(height: 44)
            .padding(.horizontal, 20)

            if !compact {
                Text("深呼吸").font(.dp(28, .heavy))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .allowsHitTesting(false)
            }
            HStack {
                sceneLabel
                Spacer()
                if current?.image != nil {
                    Text("Photo: Unsplash").font(.dp(10, .semibold)).foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .allowsHitTesting(false)
            if !compact && startedAt == nil {
                HStack { if !AppMode.launch { roadPill }; Spacer() }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }

            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().fill(Color.white.opacity(0.12)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.45), lineWidth: 2))
                    .shadow(color: Color.black.opacity(0.35), radius: 30)
                    .frame(width: 270, height: 270)
                    .scaleEffect(CGFloat(scale))
                Circle()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 330, height: 330)
                    .scaleEffect(CGFloat(0.78 + 0.22 * (startedAt == nil ? 0.5 : (1 - cos((inCycle - 0.4) / cycle * 2 * .pi)) / 2)))
                VStack(spacing: 6) {
                    DogView(size: 104, mood: finished ? .happy : (startedAt == nil ? .normal : .sleep))
                        .offset(y: -6 * CGFloat(wave))
                    if finished {
                        Text("できた！").font(.num(40))
                        if !AppMode.launch { Text("+10 ⭐").font(.dp(14, .heavy)).foregroundColor(DP.yellow) }
                    } else if startedAt != nil {
                        Text(clock(remain)).font(.num(40))
                        Text(inhale ? "すって…" : "はいて…").font(.dp(15, .bold)).foregroundColor(Color(hex: 0xD8D2FF))
                    } else {
                        Text("\(lengths[lengthIndex])分").font(.num(40))
                        Text("いっしょに深呼吸しよ？").font(.dp(14, .bold)).foregroundColor(Color(hex: 0xD8D2FF))
                    }
                }
            }
            .frame(height: 360)
            .allowsHitTesting(false)

            Spacer(minLength: 0)

            if startedAt == nil {
                VStack(spacing: 14) {
                    if !AppMode.launch { soundChips.padding(.horizontal, -20) }
                    HStack(spacing: 8) {
                        ForEach(lengths.indices, id: \.self) { i in
                            Button { Haptic.select(); lengthIndex = i; finished = false } label: {
                                Chip(label: "\(lengths[i])分", on: lengthIndex == i)
                            }
                            .buttonStyle(PressStyle())
                        }
                    }
                    Button {
                        finished = false
                        lastHapticStep = -1
                        startedAt = Date()
                    } label: {
                        Label("いっしょに深呼吸", systemImage: "play.fill")
                    }
                    .buttonStyle(PuffyStyle(color: .purple, height: 60))
                }
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 10) {
                    Text("景色を見ながらでも、目をとじてもOK").font(.dp(12, .bold)).foregroundColor(.white.opacity(0.8))
                    Button {
                        if let s = startedAt { record(Date().timeIntervalSince(s)) }
                        startedAt = nil
                    } label: { Image(systemName: "pause.fill").font(.system(size: 24, weight: .heavy)) }
                        .buttonStyle(PuffyStyle(color: .black, height: 72, circle: true))
                        .accessibilityLabel(Text("おわる"))
                }
            }
            Spacer().frame(height: compact ? 30 : 20)
        }
    }

    /// すう間は だんだん強く、はく間は だんだん弱く トントン
    private func tick(_ now: Date) {
        guard let s = startedAt else { return }
        let t = now.timeIntervalSince(s)
        if t >= total {
            startedAt = nil
            finished = true
            game.stars += 10
            record(total)
            Haptic.success()
            return
        }
        let step = Int(t / 0.25)
        guard step != lastHapticStep else { return }
        lastHapticStep = step
        let inCycle = t.truncatingRemainder(dividingBy: cycle)
        let half = cycle / 2
        if inCycle < half {
            Haptic.soft(CGFloat(0.25 + 0.75 * inCycle / half))
        } else if step % 2 == 0 {
            Haptic.soft(CGFloat(max(0.15, 1 - (inCycle - half) / half)))
        }
    }

    private func clock(_ t: Double) -> String {
        let s = Int(ceil(t))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

