import SwiftUI

/// 部屋（ホーム）
struct RoomView: View {
    @EnvironmentObject var game: GameState
    @Binding var tab: DPTab

    @State private var tipIndex = 0
    @State private var reaction: String?
    @State private var squish = false
    @State private var hop = false
    @State private var pets = 0
    @State private var stroking = false
    @State private var strokeDist: CGFloat = 0
    @State private var lastDrag: CGPoint?
    @State private var lean: CGFloat = 0          // 指のほうへ すこし かたむく（-1〜1）
    @State private var hearts: [UUID] = []
    @State private var showSettings = false
    @State private var showGacha = false
    @State private var showNight = false
    @State private var pose = DogPose()
    @StateObject private var talk = DogTalk()
    @State private var parrot = false
    @State private var acting = false             // さわり反応・しつもん中は アイドルをお休み
    @State private var nextIdle = Date().addingTimeInterval(8)

    private let tips = [
        ("ドパ抜きちゃんより", DP.yellow, "きょうもひらいてくれて、えらい！"),
        ("からだ", DP.green, "水、きょうは飲めた？"),
        ("デトックス", DP.blue, "通知、ぜんぶ切ってみない？"),
        ("スマホの代わりに", DP.orange, "ひまなら、5分だけ散歩いこ！"),
        ("やりたいこと", DP.violet, "英語、きょうもやった？"),
    ]
    /// 「スマホの代わりに」は、いまの時間帯のおすすめからランダムに
    @State private var altPick = Alternatives.forNow.prefix(4).randomElement()!
    private func tip(_ i: Int) -> (String, Color, String) {
        let t = tips[i % tips.count]
        if t.0 == "スマホの代わりに" {
            return (t.0, t.1, "\(altPick.emoji) \(altPick.title)、してみない？")
        }
        return t
    }

    private let petLines = ["えへへ〜", "そこ、きもちいい〜", "もっと〜！", "だいすき！", "ふにゃ〜…しあわせ"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                topBar
                roomCard
                Button { game.flow = .pick } label: {
                    Label("時間を取り戻す", systemImage: "play.fill")
                }
                .buttonStyle(PuffyStyle(color: .blue, height: 60))
                .padding(.top, 2)
                tiles
                todayCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(TopGlow(color: roomTint.opacity(0.55), reach: 0.4))
        .sheet(isPresented: $showSettings) { ContentView() }
        .sheet(isPresented: $showGacha) { GachaView().environmentObject(game) }
        .sheet(isPresented: $showNight) { NightLockSheet() }
        .overlay(alignment: .top) { nightToast }
    }

    // MARK: 上のバー

    private var topBar: some View {
        HStack(spacing: 8) {
            stat("flame.fill", DP.orange, "\(game.streak)")
            stat("star.fill", DP.yellow, game.stars.formatted())
            Button { showGacha = true } label: { stat("circle.hexagongrid.fill", .white, "\(game.bones)") }
                .buttonStyle(PressStyle())
            Spacer()
            #if !DEMO
            Button { showSettings = true } label: { CircleIcon(system: "gearshape") }
                .buttonStyle(PressStyle())
                .accessibilityLabel(Text("設定"))
            #endif
        }
    }

    private func stat(_ icon: String, _ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundColor(color)
            Text(text).font(.num(14)).foregroundColor(.white)
        }
        .padding(.horizontal, 11)
        .frame(height: 32)
        .background(Capsule().fill(Color.white.opacity(0.08)))
    }

    // MARK: 部屋（時間で色が変わる）

    private var hour: Int { Calendar.current.component(.hour, from: Date()) }
    private var roomTint: Color {
        switch hour {
        case 5..<10: return DP.orange
        case 10..<16: return DP.blue
        case 16..<19: return DP.pink
        default: return DP.purple
        }
    }
    private var isNight: Bool { hour >= 19 || hour < 5 }

    private var roomCard: some View {
        GeometryReader { geo in
        let cx = geo.size.width / 2
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [roomTint.opacity(0.9), roomTint.opacity(0.35), DP.card],
                                     startPoint: .top, endPoint: .bottom))
            // 窓
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isNight ? Color(hex: 0x10163A) : Color(hex: 0xBFE3FF))
                .overlay(
                    Group {
                        if isNight {
                            Circle().fill(DP.yellow).frame(width: 18, height: 18).offset(x: 16, y: -14)
                        } else {
                            Circle().fill(Color.white).frame(width: 22, height: 22).offset(x: 14, y: -12)
                        }
                    }
                )
                .overlay(Rectangle().fill(Color.white.opacity(0.5)).frame(width: 3))
                .overlay(Rectangle().fill(Color.white.opacity(0.5)).frame(height: 3))
                .frame(width: 96, height: 84)
                .position(x: 80, y: 92)
            // 床とラグ
            Ellipse().fill(Color.black.opacity(0.25)).frame(width: 250, height: 60).position(x: cx, y: 300)
            Ellipse().fill(DP.pink.opacity(0.55)).frame(width: 190, height: 44).position(x: cx, y: 300)
            // ごはん皿
            Ellipse().fill(Color(hex: 0xE0E0E0)).frame(width: 44, height: 16).position(x: cx + 105, y: 318)

            // 犬（指でなでる。タップでも ちょっとよろこぶ）
            DogView(size: 170, mood: (reaction != nil || stroking) ? .happy : (sleeping ? .sleep : .normal), pose: livePose)
                .scaleEffect(x: squish ? 1.12 : (stroking ? 1.05 : 1), y: squish ? 0.86 : (stroking ? 0.95 : 1), anchor: .bottom)
                .rotationEffect(.degrees(Double(lean) * 7), anchor: .bottom)
                .offset(y: hop ? -26 : 0)
                .bob(4, period: 2.8)
                .contentShape(Rectangle())
                .gesture(strokeGesture)
                .position(x: cx, y: 228)
                .accessibilityElement()
                .accessibilityLabel(Text("ドパ抜きちゃん。指でなでてね"))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { pet() }

            // まねっこ
            Button {
                Haptic.select()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { parrot.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: parrot ? "waveform" : "waveform.slash").font(.system(size: 11, weight: .bold))
                    Text("まねっこ").font(.dp(12, .heavy))
                }
                .foregroundColor(parrot ? .black : .white)
                .padding(.horizontal, 10).frame(height: 28)
                .background(Capsule().fill(parrot ? DP.yellow : Color.black.opacity(0.4)))
            }
            .buttonStyle(PressStyle())
            .position(x: 80, y: 156)

            ForEach(hearts, id: \.self) { id in
                FloatingHeart(id: id) { hearts.removeAll { $0 == id } }
                    .position(x: cx, y: 150)
            }

            // ふきだし
            VStack {
                if let r = reaction {
                    Bubble(text: r).transition(.scale(scale: 0.6).combined(with: .opacity))
                } else {
                    Button {
                        tipIndex += 1; altPick = Alternatives.forNow.prefix(4).randomElement()!
                    } label: {
                        let t = tip(tipIndex)
                        VStack(spacing: 2) {
                            Text(t.0).font(.dp(10, .heavy)).foregroundColor(t.1)
                            Text(t.2).font(.dp(14, .bold)).foregroundColor(.white)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.black.opacity(0.6)))
                    }
                    .buttonStyle(PressStyle())
                }
                Spacer()
            }
            .padding(.top, 16)
            .padding(.leading, 120)
            .padding(.trailing, 12)

            // 下：Lv と なでる・ごはん
            VStack {
                Spacer()
                HStack(alignment: .center, spacing: 10) {
                    levelPill
                    Spacer(minLength: 0)
                    micButton
                    Button(action: feed) { Image(systemName: "fork.knife").font(.system(size: 19, weight: .bold)) }
                        .buttonStyle(PuffyStyle(color: .yellow, height: 50, circle: true))
                        .accessibilityLabel(Text("ごはんをあげる"))
                }
                .padding(14)
                .padding(.bottom, 4)
            }
        }
        }
        .frame(height: 420)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in idleTick(now) }
        .onAppear { nightNotice() }
        .onChange(of: showNight) { open in if !open { nightNotice() } }
        #if DEBUG
        .onAppear {
            // スクショ確認用: -debugAct sneeze|ear|tickle|yawn|ask
            let sheet = UserDefaults.standard.string(forKey: "debugSheet")
            if sheet == "gacha" { showGacha = true }
            if sheet == "night" { showNight = true }
            guard let act = UserDefaults.standard.string(forKey: "debugAct") else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                switch act {
                case "sneeze": sneeze()
                case "ear": earFlap()
                case "tickle": tickle()
                case "yawn": steps([(0, { $0.eyes = .sleep; $0.mouthOpen = 1 }), (3, { $0.mouthOpen = 0 })])
                default: answer()
                }
            }
        }
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var levelPill: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Lv.\(game.level)").font(.num(15)).foregroundColor(.white)
                if let n = game.nextStage {
                    Text("\(n.name)まで あと\(n.hoursLeft)時間").font(.dp(11, .bold)).foregroundColor(DP.gray)
                } else {
                    Text(game.stageName).font(.dp(11, .bold)).foregroundColor(DP.gray)
                }
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule().fill(LinearGradient(colors: [DP.pink, DP.yellow], startPoint: .leading, endPoint: .trailing))
                        .frame(width: g.size.width * CGFloat(game.nextStage?.progress ?? 1))
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: 190)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.45)))
    }

    // MARK: おやすみ

    private var sleeping: Bool { NightLock.isOn && NightLock.isSleepTime() }

    private var nightTileText: String {
        if !NightLock.isOn { return "オフ" }
        if !NightLock.isReady { return "設定する" }
        return "今夜 " + NightLock.rangeText
    }

    @ViewBuilder
    private var nightToast: some View {
        if let m = game.nightToast {
            HStack(spacing: 10) {
                DogView(size: 44, mood: .happy)
                Text("おはよう！ねてる間に\(m / 60)時間取り戻したよ").font(.dp(14, .heavy))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(DP.purple))
            .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onTapGesture { withAnimation { game.nightToast = nil } }
            .onAppear {
                Haptic.success()
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { withAnimation { game.nightToast = nil } }
            }
        }
    }

    // MARK: タイル

    private var tiles: some View {
        HStack(spacing: 10) {
            tile("sparkles", DP.yellow, "ガチャ", "ほね\(game.bones)こ") { showGacha = true }
            tile("person.3.fill", DP.green, "ひろば", "3人が置いてる") { tab = .friends }
            tile("moon.fill", DP.violet, "おやすみ", nightTileText) { showNight = true }
        }
    }

    private func tile(_ icon: String, _ color: Color, _ title: String, _ sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(color))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.dp(14, .heavy)).foregroundColor(.white)
                    Text(sub).font(.dp(11, .semibold)).foregroundColor(DP.gray).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
        }
        .buttonStyle(PressStyle())
    }

    // MARK: きょう取り戻した時間

    private var todayCard: some View {
        ZStack(alignment: .topLeading) {
            DP.purple
            Blob(color: DP.pink, size: 220, period: 11).offset(x: 190, y: -70)
            Blob(color: DP.green.opacity(0.9), size: 180, period: 9, offset: 0.4).offset(x: 40, y: 150)
            VStack(alignment: .leading, spacing: 10) {
                Text("きょう取り戻した時間").font(.dp(12, .heavy)).foregroundColor(.white.opacity(0.85))
                TodayNumber(minutes: game.todayMinutes)
                HStack(spacing: 8) {
                    Text(movieText).font(.dp(13, .heavy)).foregroundColor(DP.yellow)
                    Text(diffText).font(.dp(12, .bold)).foregroundColor(.white.opacity(0.8))
                }
                HStack(spacing: 0) {
                    miniStat("今週", hm(game.weekMinutes))
                    miniStat("れんぞく", "\(game.streak)日")
                    miniStat("ぜんぶで", "\(game.totalMinutes / 60)h")
                }
                .padding(.top, 6)
            }
            .padding(20)
        }
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var movieText: String {
        let m = game.todayMinutes
        if m >= 240 { return "映画\(m / 120)本ぶん！" }
        if m >= 120 { return "映画1本ぶん！" }
        if m >= 30 { return "アニメ\(m / 24)話ぶん！" }
        return "まだまだ、これから！"
    }
    private var diffText: String {
        let d = game.todayMinutes - game.yesterdayMinutes
        return d >= 0 ? "きのうより +\(d)分" : "きのうまで あと\(-d)分"
    }
    private func hm(_ m: Int) -> String { "\(m / 60)h\(m % 60)m" }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.dp(11, .bold)).foregroundColor(.white.opacity(0.75))
            Text(value).font(.num(17)).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 動き

    /// 指でなでる：なでた距離が 70pt たまるごとにハート
    private var strokeGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if !stroking {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { stroking = true }
                }
                if let last = lastDrag {
                    strokeDist += hypot(v.location.x - last.x, v.location.y - last.y)
                }
                lastDrag = v.location
                withAnimation(.interactiveSpring()) { lean = max(-1, min(1, (v.location.x - 85) / 85)) }
                if strokeDist >= 70 {
                    strokeDist = 0
                    stroke()
                }
            }
            .onEnded { v in
                let moved = hypot(v.translation.width, v.translation.height)
                if moved < 8 { touch(at: v.location) }    // タップ：さわった場所で反応がかわる
                lastDrag = nil
                strokeDist = 0
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    stroking = false
                    lean = 0
                }
            }
    }

    // MARK: いきてる ドパ抜きちゃん

    /// しつもん中・まねっこ中の耳や口も まぜた ポーズ
    private var livePose: DogPose {
        var p = pose
        if talk.listening {
            p.earsUp = true
            if p.headTilt == 0 { p.headTilt = 8 }
            if p.eyes == nil { p.eyes = .normal }
        }
        if talk.playing { p.mouthOpen = max(p.mouthOpen, talk.playLevel) }
        return p
    }

    /// 体のどこをさわったか（DogView は 120 の絵を 170 に拡大している）
    private func touch(at loc: CGPoint) {
        let p = CGPoint(x: loc.x * 120 / 170, y: loc.y * 120 / 170)
        func near(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Bool { hypot(p.x - x, p.y - y) < r }
        if near(60, 61, 8) { sneeze() }
        else if near(29, 50, 15) || near(91, 50, 15) { earFlap() }
        else if p.x > 82 && p.y > 70 && p.y < 104 { wag(text: "しっぽ、ふりふり〜") }
        else if p.y > 78 && p.x > 32 && p.x < 88 { tickle() }
        else { pet() }
    }

    /// 時間をずらして、なめらかに ポーズをかえる
    private func steps(_ list: [(Double, (inout DogPose) -> Void)], done: (() -> Void)? = nil) {
        acting = true
        var t = 0.0
        for (dt, change) in list {
            t += dt
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { change(&pose) }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + t + 0.25) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { pose = DogPose() }
            acting = false
            nextIdle = Date().addingTimeInterval(Double.random(in: 6...12))
            done?()
        }
    }

    private func say(_ text: String) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { reaction = text }
        clearReactionLater()
    }

    /// おやすみロックの予告（はじめての夜・時間をかえたとき）
    private func nightNotice() {
        guard let text = NightLock.takeNotice() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            Haptic.soft()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { reaction = text }
            reactionToken += 1
            let token = reactionToken
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if token == reactionToken { withAnimation(.easeOut(duration: 0.25)) { reaction = nil } }
            }
        }
    }

    private func sneeze() {
        Haptic.rigid()
        say("くしゅん！")
        steps([
            (0, { $0.eyes = .sleep; $0.mouthOpen = 0.3 }),
            (0.18, { $0.mouthOpen = 1; $0.headTilt = -6 }),
            (0.08, { $0.headTilt = 7 }),
            (0.08, { $0.headTilt = -5 }),
            (0.08, { $0.headTilt = 3; $0.mouthOpen = 0 }),
        ])
    }

    private func earFlap() {
        Haptic.light()
        say("みみはダメ〜")
        steps([
            (0, { $0.earAngle = 30; $0.eyes = .sleep }),
            (0.12, { $0.earAngle = -10 }),
            (0.12, { $0.earAngle = 30 }),
            (0.12, { $0.earAngle = -10 }),
            (0.12, { $0.earAngle = 0 }),
        ])
    }

    private func tickle() {
        Haptic.soft()
        say("くすぐった〜い！")
        steps([
            (0, { $0.eyes = .happy; $0.mouthOpen = 0.8; $0.headTilt = -9 }),
            (0.1, { $0.headTilt = 9 }),
            (0.1, { $0.headTilt = -9 }),
            (0.1, { $0.headTilt = 9 }),
            (0.1, { $0.headTilt = 0; $0.mouthOpen = 0.4 }),
        ])
        for i in 0..<4 { DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) { Haptic.soft(0.5) } }
    }

    private func wag(text: String?) {
        if let t = text { Haptic.select(); say(t) }
        var list: [(Double, (inout DogPose) -> Void)] = []
        for i in 0..<6 { list.append((i == 0 ? 0 : 0.13, { $0.tailWag = i % 2 == 0 ? 22 : -14 })) }
        list.append((0.13, { $0.tailWag = 0 }))
        steps(list)
    }

    /// 6〜12秒ごとに、ひとりで うごく
    private func idleTick(_ now: Date) {
        guard now >= nextIdle, !acting, !stroking, !talk.listening, !talk.playing, reaction == nil, !sleeping else { return }
        nextIdle = now.addingTimeInterval(Double.random(in: 6...12))
        switch Int.random(in: 0..<4) {
        case 0:  // あくび
            steps([(0, { $0.eyes = .sleep; $0.mouthOpen = 0.4 }), (0.25, { $0.mouthOpen = 1 }), (0.9, { $0.mouthOpen = 0 })])
        case 1:  // きょろきょろ
            steps([(0, { $0.headTilt = -10 }), (0.6, { $0.headTilt = 10 }), (0.6, { $0.headTilt = 0 })])
        case 2:  // 耳ぴくっ
            steps([(0, { $0.earAngle = 14 }), (0.12, { $0.earAngle = 0 }), (0.3, { $0.earAngle = 14 }), (0.12, { $0.earAngle = 0 })])
        default:
            wag(text: nil)
        }
    }

    // MARK: しつもん・まねっこ

    private var micButton: some View {
        ZStack {
            Circle().strokeBorder(DP.yellow.opacity(0.8), lineWidth: 3)
                .frame(width: 50, height: 50)
                .scaleEffect(1 + talk.level * 0.5)
                .opacity(talk.listening ? 1 : 0)
                .animation(.easeOut(duration: 0.08), value: talk.level)
            Image(systemName: talk.listening ? "mic.fill" : "mic")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 50, height: 50)
                .background(
                    ZStack {
                        Circle().fill(Color(hex: 0x9A9A9A)).offset(y: talk.listening ? 1 : 4)
                        Circle().fill(LinearGradient(colors: [.white, Color(hex: 0xDADADA)], startPoint: .top, endPoint: .bottom))
                    }
                )
                .offset(y: talk.listening ? 3 : 0)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !talk.listening, !talk.playing, !acting else { return }
                    Haptic.medium()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { reaction = parrot ? "まねするよ、しゃべって！" : "なになに？" }
                    talk.begin()
                }
                .onEnded { _ in
                    guard talk.listening else { return }
                    let recorded = talk.end()
                    if parrot { parrotBack(recorded) } else { answer() }
                }
        )
        .accessibilityLabel(Text(parrot ? "おして話すと、まねするよ" : "おしながら しつもんしてね"))
        .accessibilityAddTraits(.isButton)
    }

    private func parrotBack(_ recorded: Bool) {
        guard recorded, !talk.micDenied else {
            say(talk.micDenied ? "マイクがつかえないみたい…" : "きこえなかった〜")
            return
        }
        acting = true
        withAnimation { reaction = "♪" }
        talk.playBack()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            acting = false
            clearReactionLater()
        }
    }

    private func answer() {
        acting = true
        withAnimation(.spring()) { reaction = "んー…"; pose.headTilt = 10; pose.eyes = .sleep }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            acting = false
            switch Int.random(in: 0..<5) {
            case 0:
                Haptic.success(); say("うん！")
                steps([(0, { $0.eyes = .happy; $0.mouthOpen = 0.7; $0.headTilt = 0 })])
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { hop = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { withAnimation(.spring()) { hop = false } }
            case 1:
                Haptic.light(); say("ううん")
                steps([(0, { $0.eyes = .normal; $0.headTilt = -12 }), (0.15, { $0.headTilt = 12 }),
                       (0.15, { $0.headTilt = -10 }), (0.15, { $0.headTilt = 0 })])
            case 2:
                Haptic.soft(); say("えへへ")
                steps([(0, { $0.eyes = .happy; $0.headTilt = 6; $0.tailWag = 22 }), (0.13, { $0.tailWag = -14 }),
                       (0.13, { $0.tailWag = 22 }), (0.13, { $0.tailWag = 0 })])
            case 3:
                Haptic.select(); say("たぶんね")
                steps([(0, { $0.eyes = .normal; $0.headTilt = 14; $0.earAngle = 8 }), (0.8, { $0.headTilt = 0 })])
            default:
                Haptic.rigid(); say("スマホ置いたら教える〜")
                steps([(0, { $0.eyes = .happy; $0.mouthOpen = 0.5; $0.headTilt = -6 }), (0.9, { $0.mouthOpen = 0 })])
            }
        }
    }

    private func stroke() {
        Haptic.soft(0.7)
        pets += 1
        hearts.append(UUID())
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            reaction = petLines[(pets - 1) % petLines.count]
        }
        clearReactionLater()
    }

    private func pet() {
        Haptic.soft()
        pets += 1
        hearts.append(UUID())
        withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) {
            squish = true
            reaction = petLines[(pets - 1) % petLines.count]
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.35)) { squish = false }
        }
        clearReactionLater()
    }

    private func feed() {
        guard game.bones > 0 else {
            withAnimation(.spring()) { reaction = "ほねがないよ〜。スマホ置いてこよ？" }
            Haptic.soft(0.6)
            clearReactionLater()
            return
        }
        game.bones -= 1
        Haptic.success()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
            hop = true
            reaction = "おいしい〜！"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.4)) { hop = false }
        }
        clearReactionLater()
    }

    @State private var reactionToken = 0
    private func clearReactionLater() {
        reactionToken += 1
        let token = reactionToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if token == reactionToken { withAnimation(.easeOut(duration: 0.25)) { reaction = nil } }
        }
    }
}

/// きょうの時間（カウントアップ）
private struct TodayNumber: View {
    var minutes: Int
    @State private var shown: Double = 0
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            CountUp(value: Double(Int(shown) / 60), font: .num(64), grouped: false)
            Text("時間").font(.dp(16, .heavy)).foregroundColor(.white)
            CountUp(value: Double(Int(shown) % 60), font: .num(64), grouped: false)
            Text("分").font(.dp(16, .heavy)).foregroundColor(.white)
        }
        .onAppear {
            shown = 0
            withAnimation(.easeOut(duration: 1.4).delay(0.2)) { shown = Double(minutes) }
        }
        .onChange(of: minutes) { m in
            withAnimation(.easeOut(duration: 1.2)) { shown = Double(m) }
        }
    }
}

/// なでたときに出るハート
private struct FloatingHeart: View {
    let id: UUID
    let done: () -> Void
    @State private var up = false
    private let dx = CGFloat.random(in: -40...40)
    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 22))
            .foregroundColor(DP.pink)
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

/// ガチャ（ほね1こで1回）
struct GachaView: View {
    @EnvironmentObject var game: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var result: (String, String, Color)?
    @State private var shake = false
    @State private var pop = false

    private let pool: [(String, String, Color)] = [
        ("ふかふかクッション", "ふつう", DP.gray),
        ("まるいラグ", "ふつう", DP.gray),
        ("観葉植物", "ふつう", DP.gray),
        ("木の本だな", "レア", DP.blue),
        ("星のランプ", "レア", DP.blue),
        ("ちいさな地球儀", "レア", DP.blue),
        ("虹のハンモック", "ちょうレア", DP.pink),
    ]

    var body: some View {
        ZStack {
            TopGlow(color: Color(hex: 0x6B4A00), reach: 0.5)
            if result != nil { Confetti().ignoresSafeArea() }
            VStack(spacing: 22) {
                HStack {
                    Button { dismiss() } label: { CircleIcon(system: "xmark") }.buttonStyle(PressStyle())
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "circle.hexagongrid.fill").foregroundColor(.white)
                        Text("\(game.bones)").font(.num(15))
                    }
                    .padding(.horizontal, 12).frame(height: 32)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                }
                Text("ガチャ").font(.dp(30, .heavy)).frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                if let r = result {
                    VStack(spacing: 14) {
                        Text("GET!").font(.num(22)).foregroundColor(DP.yellow)
                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(DP.card)
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(r.1 == "ちょうレア"
                                              ? AnyShapeStyle(AngularGradient(colors: [DP.pink, DP.yellow, DP.green, DP.blue, DP.violet, DP.pink], center: .center))
                                              : AnyShapeStyle(r.2), lineWidth: 3)
                            VStack(spacing: 10) {
                                Image(systemName: "gift.fill").font(.system(size: 54)).foregroundColor(r.2 == DP.gray ? .white : r.2)
                                Text(r.0).font(.dp(20, .heavy))
                                Text(r.1).font(.dp(12, .heavy)).foregroundColor(r.2)
                            }
                        }
                        .frame(width: 240, height: 220)
                        .scaleEffect(pop ? 1 : 0.5)
                        .opacity(pop ? 1 : 0)
                    }
                } else {
                    ZStack {
                        Circle().fill(DP.yellow.opacity(0.25)).frame(width: 230, height: 230).blur(radius: 30)
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 110))
                            .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE28A), Color(hex: 0xE59A00)], startPoint: .top, endPoint: .bottom))
                            .rotationEffect(.degrees(shake ? 8 : 0))
                    }
                }
                Spacer()
                Button(action: roll) {
                    Text(game.bones > 0 ? "ほね1こで まわす" : "ほねがないよ")
                }
                .buttonStyle(PuffyStyle(color: .yellow, height: 60))
                .disabled(game.bones == 0)
                .opacity(game.bones == 0 ? 0.5 : 1)
                Text("ほねは、スマホを30分置くとたまるよ").font(.dp(12, .semibold)).foregroundColor(DP.gray)
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
    }

    private func roll() {
        guard game.bones > 0 else { return }
        game.bones -= 1
        result = nil
        pop = false
        withAnimation(.easeInOut(duration: 0.08).repeatCount(7, autoreverses: true)) { shake = true }
        for i in 0..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) { Haptic.rigid() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            shake = false
            let roll = Int.random(in: 0..<100)
            let r = roll < 8 ? pool[6] : (roll < 38 ? pool[Int.random(in: 3...5)] : pool[Int.random(in: 0...2)])
            result = r
            game.items.append(r.0)
            Haptic.success()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { pop = true }
        }
    }
}
