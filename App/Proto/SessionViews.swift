import SwiftUI

/// セッション：えらぶ → 取り戻し中 → 結果
struct SessionFlowView: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        ZStack {
            DP.bg.ignoresSafeArea()
            switch game.flow {
            case .pick, .none:
                if AppMode.launch {
                    LaunchPickView().transition(.opacity)
                } else {
                    SessionPickView().transition(.opacity)
                }
            case .base:
                BaseView().transition(.opacity)
            case .declare:
                DeclareView().transition(.opacity)
            case .running:
                SessionRunView().transition(.move(edge: .bottom).combined(with: .opacity))
            case .result(let r):
                if AppMode.launch {
                    WelcomeBackView(result: r).transition(.scale(scale: 0.9).combined(with: .opacity))
                } else {
                    ResultView(result: r).transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: game.flow)
        .preferredColorScheme(.dark)
    }
}

// MARK: - えらぶ

/// 長さの単位（分・時間・日・週）
enum LengthUnit: Int, CaseIterable {
    case minute, hour, day, week
    var label: String { ["分", "時間", "日", "週"][rawValue] }
    var range: ClosedRange<Double> { [5...90, 1...24, 1...6, 1...4][rawValue] }
    var step: Double { self == .minute ? 5 : 1 }
    var perUnit: Int { [1, 60, 24 * 60, 7 * 24 * 60][rawValue] }
    func title(_ v: Int) -> String {
        switch self {
        case .minute: return "\(v)分"
        case .hour: return "\(v)時間"
        case .day: return "\(v)日間"
        case .week: return "\(v)週間"
        }
    }
}

struct SessionPickView: View {
    @EnvironmentObject var game: GameState
    @State private var sel = -1          // -1 = きょうのおすすめ, 0 = 自分で長さをきめる
    @AppStorage("p.lenUnit") private var unitRaw = 0
    @AppStorage("p.lenValue") private var value: Double = 25
    @AppStorage("p.lenCustom") private var lastCustom = false   // 前回「長さをきめる」を選んだか
    @State private var lives = 3
    @State private var peekMin = 5
    @State private var useBase = true
    @State private var declare = false
    @State private var loaded = false
    @State private var showSettings = false

    private var unit: LengthUnit { LengthUnit(rawValue: unitRaw) ?? .minute }
    private var goalMinutes: Int { sel == -1 ? minutesUntil8am : Int(value) * unit.perUnit }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button { game.cancelPick() } label: { CircleIcon(system: "xmark") }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel(Text("とじる"))
                Spacer()
            }
            Text("時間を取り戻す").font(.dp(28, .heavy))

            ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
            Button { Haptic.select(); declare.toggle() } label: {
                HStack(spacing: 5) {
                    Image(systemName: declare ? "megaphone.fill" : "megaphone").font(.system(size: 12, weight: .bold))
                    Text("宣言してはじめる").font(.dp(13, .bold))
                    if declare { Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)) }
                }
                .foregroundColor(declare ? .black : .white)
                .padding(.horizontal, 14).frame(height: 34)
                .background(Capsule().fill(declare ? DP.yellow : DP.card2))
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel(Text("宣言してはじめる"))
            .accessibilityValue(Text(declare ? "オン" : "オフ"))
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { Haptic.select(); sel = -1 } label: { featured }
                .buttonStyle(PressStyle(scale: 0.97))

            lengthPicker

            rules
            }
            .padding(.bottom, 8)
            }

            HStack(spacing: 6) {
                Text("⭐ +\(previewStars.formatted())").font(.num(15)).foregroundColor(DP.yellow)
                Text("×" + String(format: "%.1f", mult)).font(.num(13))
                    .foregroundColor(mult > 1 ? DP.yellow : .white)
                if goalMinutes >= 30 {
                    Text("🦴\(goalMinutes / 30)").font(.num(13))
                }
                if let b = badge {
                    Text(b).font(.dp(11, .heavy)).foregroundColor(.black)
                        .padding(.horizontal, 8).frame(height: 22)
                        .background(Capsule().fill(DP.yellow))
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.spring(), value: mult)

            if needsSetup {
                Button { showSettings = true } label: {
                    Label("ブロックするアプリを えらぶ", systemImage: "gearshape.fill")
                }
                .buttonStyle(PuffyStyle(color: .yellow, height: 60))
                Text("先に えらんでおくと、セッション中に ちゃんとブロックされるよ")
                    .font(.dp(12, .bold)).foregroundColor(DP.gray).frame(maxWidth: .infinity)
            } else {
                Button { game.start(plan) } label: {
                    Label(plan.title + "ではじめる", systemImage: "play.fill")
                }
                .buttonStyle(PuffyStyle(color: .blue, height: 60))
            }
        }
        .sheet(isPresented: $showSettings) { BlockSettingsView() }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            lives = game.maxLives
            peekMin = game.peekMinutes
            useBase = game.useBase
            declare = game.useDeclare
            sel = lastCustom ? 0 : -1
        }
        .onChange(of: sel) { v in lastCustom = v == 0 }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(TopGlow(color: DP.navy, reach: 0.4))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: sel)
    }

    /// ブロックするアプリが まだ決まっていない（デモ版はブロックしないので不要）
    private var needsSetup: Bool {
        #if DEMO
        return false
        #else
        _ = showSettings   // シートを閉じたら もう一度しらべる
        return !(NightLock.isAuthorized && NightLock.hasTargets)
        #endif
    }

    /// ⭐ のめやす（ゴールまで置けたら）
    private var previewStars: Int { Int((Double(goalMinutes) * mult).rounded()) }
    private var badge: String? {
        if goalMinutes >= 7 * 24 * 60 { return "レア家具" }
        if goalMinutes >= 3 * 24 * 60 { return "ガチャ+1" }
        return nil
    }

    /// 単位（分・時間・日・週）＋スライダー
    private var lengthPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(LengthUnit.allCases, id: \.rawValue) { u in
                    Button {
                        Haptic.select()
                        sel = 0
                        unitRaw = u.rawValue
                        value = min(max(value, u.range.lowerBound), u.range.upperBound)
                        if u == .minute { value = max(5, (value / 5).rounded() * 5) }
                    } label: { Chip(label: u.label, on: sel == 0 && unit == u).fixedSize() }
                    .buttonStyle(PressStyle())
                }
                Spacer(minLength: 0)
                Button {
                    Haptic.success()
                    sel = 0; unitRaw = LengthUnit.week.rawValue; value = 1
                } label: { Label("1週間", systemImage: "crown.fill").font(.dp(13, .heavy)).lineLimit(1).fixedSize() }
                    .buttonStyle(PuffyStyle(color: .yellow, height: 36, fullWidth: false))
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(value))").font(.num(48)).foregroundColor(sel == 0 ? .white : DP.dim)
                Text(unit == .week ? "週間" : unit.label).font(.dp(20, .heavy))
                    .foregroundColor(sel == 0 ? .white : DP.dim)
                Spacer()
                if sel == 0 && unit == .minute && value <= 10 {
                    Text("ミニデトックス").font(.dp(12, .heavy)).foregroundColor(DP.yellow)
                }
            }
            Slider(value: Binding(get: { value }, set: { value = $0; sel = 0 }), in: unit.range, step: unit.step)
                .tint(DP.blue)
                .onChange(of: value) { _ in Haptic.select() }
            HStack {
                Text(unit.title(Int(unit.range.lowerBound))).font(.dp(11, .bold)).foregroundColor(DP.dim)
                Spacer()
                Text(unit.title(Int(unit.range.upperBound))).font(.dp(11, .bold)).foregroundColor(DP.dim)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white, lineWidth: sel == 0 ? 2 : 0))
    }

    static let peekSteps = [1, 3, 5, 10, 15, 20, 30, 45, 60]

    private var mult: Double { rewardMultiplier(lives: lives, peekMinutes: 0) * ((useBase || sel == -1) ? 1.2 : 1) }

    private var plan: SessionPlan {
        var p: SessionPlan
        if sel == -1 {
            p = SessionPlan(title: "あしたの朝まで", goalMinutes: minutesUntil8am)
            p.cardWhen = "あしたの朝まで"
            p.forceBase = true
        } else {
            p = SessionPlan(title: unit.title(Int(value)), goalMinutes: goalMinutes)
            p.cardWhen = Self.whenText(minutes: goalMinutes, unit: unit, value: Int(value))
        }
        p.lives = lives
        p.peekMinutes = peekMin
        p.useBase = useBase || p.forceBase
        p.declared = declare
        return p
    }

    /// 宣言カードの「いつまで」
    static func whenText(minutes: Int, unit: LengthUnit, value: Int) -> String {
        if unit == .day || unit == .week { return unit.title(value) }
        let end = Date().addingTimeInterval(Double(minutes * 60))
        let f = DateFormatter()
        f.dateFormat = "H:mm"
        let prefix = Calendar.current.isDateInToday(end) ? "" : "あした"
        return prefix + f.string(from: end) + "まで"
    }

    /// 基地スタート／基地なし、ライフ（0〜3）。中断の分数は中断するときに決める
    private var rules: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button { Haptic.select(); useBase = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill").font(.system(size: 12, weight: .bold))
                            .foregroundColor(useBase ? DP.orange : DP.yellow)
                        Text("基地スタート ⭐×1.2").font(.dp(13, .bold))
                    }
                    .foregroundColor(useBase ? .black : .white)
                    .padding(.horizontal, 14).frame(height: 34)
                    .background(Capsule().fill(useBase ? Color.white : DP.card2))
                }
                .buttonStyle(PressStyle())
                Button { Haptic.select(); useBase = false } label: { Chip(label: "基地なし", on: !useBase) }
                    .buttonStyle(PressStyle())
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                Text("ライフ").font(.dp(13, .heavy))
                Spacer()
                ForEach(0...3, id: \.self) { n in
                    Button { Haptic.select(); lives = n } label: { lifeChip(n) }
                        .buttonStyle(PressStyle())
                        .accessibilityLabel(Text("ライフ\(n)"))
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: lives)
    }

    private func lifeChip(_ n: Int) -> some View {
        let on = lives == n
        return HStack(spacing: 2) {
            if n == 0 {
                Image(systemName: "heart.slash").font(.system(size: 12, weight: .bold))
            } else {
                ForEach(0..<n, id: \.self) { _ in
                    Image(systemName: "heart.fill").font(.system(size: 10, weight: .bold))
                }
            }
        }
        .foregroundColor(on ? .black : DP.pink)
        .padding(.horizontal, 10).frame(height: 32)
        .background(Capsule().fill(on ? Color.white : Color.white.opacity(0.08)))
    }

    private var minutesUntil8am: Int {
        let cal = Calendar.current
        var target = cal.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        if target <= Date() { target = target.addingTimeInterval(86400) }
        return max(1, Int(target.timeIntervalSinceNow / 60))
    }

    private var featured: some View {
        ZStack(alignment: .topLeading) {
            DP.purple
            Blob(color: DP.pink, size: 200, period: 10).offset(x: 190, y: -60)
            Blob(color: DP.green, size: 170, period: 8, offset: 0.3).offset(x: 130, y: 90)
            VStack(alignment: .leading, spacing: 6) {
                Text("きょうのおすすめ").font(.dp(11, .heavy)).foregroundColor(.white.opacity(0.8))
                Text("今夜〜\nあしたの朝").font(.dp(24, .black)).foregroundColor(.white).lineSpacing(0)
                HStack(spacing: 4) {
                    Text("23:00→8:00 ・").font(.dp(12, .bold)).foregroundColor(.white.opacity(0.85))
                    Text("+300").font(.num(12)).foregroundColor(DP.yellow)
                }
            }
            .padding(18)
            DogView(size: 110, mood: .sleep)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 14)
                .offset(y: 8)
        }
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white, lineWidth: sel == -1 ? 3 : 0))
    }

}

// MARK: - 中断する（用途と分数を、そのときに決める）

struct PeekSheet: View {
    @EnvironmentObject var game: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var other = ""
    @State private var minutes = 5
    @FocusState private var typing: Bool

    private let reasons = ["💬 LINEの返信", "📞 連絡・電話", "🔍 調べもの", "🗺️ 地図・乗りかえ", "📷 写真", "✏️ その他"]
    private let lengths = [1, 3, 5, 10, 15, 30, 60]

    /// 記録する用途（えらんだもの or 書いたもの）
    private var purpose: String {
        let t = other.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { return t }
        guard !reason.isEmpty, !reason.hasSuffix("その他") else { return "" }
        return String(reason.split(separator: " ", maxSplits: 1).last ?? "")
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button { dismiss() } label: { CircleIcon(system: "xmark") }.buttonStyle(PressStyle())
                    Spacer()
                    HStack(spacing: 3) {
                        if !AppMode.launch {
                            ForEach(0..<game.lives, id: \.self) { _ in Image(systemName: "heart.fill").foregroundColor(DP.pink) }
                        }
                    }
                }
                HStack(spacing: 10) {
                    DogView(size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppMode.launch ? "何しに開く？" : "中断する").font(.dp(26, .heavy))
                        Text(AppMode.launch ? "ひとつ決めてから、開こうね" : "なにに使うか、きめてからね").font(.dp(13, .bold)).foregroundColor(DP.gray)
                    }
                }

                Text("なにに使う？").font(.dp(16, .heavy))
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0..<3, id: \.self) { r in
                        HStack(spacing: 8) {
                            ForEach(reasons[(r * 2)..<(r * 2 + 2)], id: \.self) { item in
                                Button {
                                    Haptic.select()
                                    reason = item
                                    if item.hasSuffix("その他") { typing = true } else { other = "" }
                                } label: { Chip(label: item, on: reason == item).fixedSize() }
                                .buttonStyle(PressStyle())
                            }
                        }
                    }
                }
                TextField("ほかに書く", text: $other)
                    .font(.dp(15, .bold))
                    .focused($typing)
                    .padding(.horizontal, 14).frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(DP.card))

                Text("何分？").font(.dp(16, .heavy))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(lengths, id: \.self) { m in
                            Button { Haptic.select(); minutes = m } label: { Chip(label: "\(m)分", on: minutes == m).fixedSize() }
                                .buttonStyle(PressStyle())
                        }
                    }
                }
                Text("中断のあいだは タイマーが止まるよ").font(.dp(12, .bold)).foregroundColor(DP.dim)

                Button {
                    game.peek(minutes: minutes, reason: purpose)
                    dismiss()
                } label: { Label(purpose.isEmpty ? "なにに使うか えらんでね" : (AppMode.launch ? "\(minutes)分だけ開く" : "\(minutes)分 中断する（ライフ−1）"), systemImage: "pause.fill") }
                    .buttonStyle(PuffyStyle(color: .white, height: 56, strong: false))
                    .disabled(purpose.isEmpty)
                    .opacity(purpose.isEmpty ? 0.5 : 1)
                Button("やっぱり つづける") { dismiss() }
                    .font(.dp(14, .heavy)).foregroundColor(DP.gray)
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .background(DP.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

// MARK: - おやすみロック：基地に置くまで すすめない

struct NightBaseView: View {
    @EnvironmentObject var game: GameState
    @State private var battery = UIDevice.BatteryState.unknown
    @State private var placed = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x10163A), DP.bg], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ForEach(0..<24, id: \.self) { i in
                Circle().fill(Color.white.opacity(0.5)).frame(width: 2, height: 2)
                    .position(x: CGFloat((i * 53) % 390), y: CGFloat((i * 97) % 300) + 60)
            }
            VStack(spacing: 18) {
                Text(placed ? "おやすみ！" : "おやすみの前に").font(.dp(30, .heavy))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                ZStack {
                    Circle().fill((placed ? DP.green : DP.violet).opacity(0.25)).frame(width: 260, height: 260).blur(radius: 30)
                    Image(systemName: placed ? "bolt.fill" : "bolt")
                        .font(.system(size: 44, weight: .heavy))
                        .foregroundColor(placed ? DP.yellow : DP.gray)
                        .frame(width: 80, height: 130)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: 0x2A2A2A)))
                        .offset(x: 60)
                    DogView(size: 140, mood: placed ? .sleep : .normal)
                        .offset(x: -60, y: 30)
                        .bob(placed ? 2 : 4, period: placed ? 3 : 2.4)
                }
                .frame(height: 280)
                Bubble(text: placed ? "いっしょに ねよ〜。また あしたね" : "おやすみの前に、基地につないでね")
                Spacer(minLength: 0)
                Text(placed ? "朝になったら、ねてた時間が「取り戻した時間」になるよ"
                            : "充電ケーブルをさすと、すすめるよ。スマホは できるだけ ベッドから遠くに")
                    .font(.dp(13, .bold)).foregroundColor(DP.gray).multilineTextAlignment(.center)
                #if DEBUG
                if battery == .unknown && !placed {
                    Button("（テスト用）基地なしで とじる") { finish(confirmed: false) }
                        .font(.dp(12, .bold)).foregroundColor(DP.dim)
                }
                #endif
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.45, dampingFraction: 0.6), value: placed)
        .onAppear { UIDevice.current.isBatteryMonitoringEnabled = true; check() }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)) { _ in check() }
    }

    private func check() {
        battery = UIDevice.current.batteryState
        guard !placed, battery == .charging || battery == .full else { return }
        placed = true
        Haptic.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { finish(confirmed: true) }
    }

    private func finish(confirmed: Bool) {
        if confirmed { game.nightBaseKey = NightLock.nightKey() }
        game.nightBaseSkipped = !confirmed
    }
}

// MARK: - 基地に置く

struct BaseView: View {
    @EnvironmentObject var game: GameState
    @State private var placed = false
    @State private var battery = UIDevice.BatteryState.unknown
    @State private var glow = false

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button { game.pendingPlan = nil; game.flow = .pick } label: { CircleIcon(system: "chevron.left") }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel(Text("もどる"))
                Spacer()
            }
            Text(placed ? "基地に置けた！" : "基地に置こう").font(.dp(30, .heavy))
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            ZStack {
                Circle().fill((placed ? DP.green : DP.yellow).opacity(glow ? 0.35 : 0.15))
                    .frame(width: 260, height: 260).blur(radius: 30)
                // 棚と充電器
                VStack(spacing: 0) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: 0x2A2A2A))
                            .frame(width: 74, height: 130)
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.3), lineWidth: 2))
                        Image(systemName: placed ? "bolt.fill" : "bolt")
                            .font(.system(size: 34, weight: .heavy))
                            .foregroundColor(placed ? DP.yellow : DP.gray)
                            .scaleEffect(placed ? 1.2 : 1)
                    }
                    .offset(y: placed ? -4 : 0)
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(hex: 0x8A5A3A))
                        .frame(width: 200, height: 14)
                }
                .offset(x: 50)
                DogView(size: 130, mood: placed ? .happy : .normal)
                    .offset(x: -80, y: 40)
                    .bob(placed ? 12 : 4, period: placed ? 0.8 : 2.4)
            }
            .frame(height: 280)

            Bubble(text: bubbleText)

            Spacer(minLength: 0)

            if placed {
                Text("⭐ ×1.2").font(.num(22)).foregroundColor(DP.yellow)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text(battery == .unknown ? "この端末では充電をたしかめられないよ" : "充電ケーブルをさすと、じどうで はじまるよ")
                    .font(.dp(13, .bold)).foregroundColor(DP.gray)
                if !(game.pendingPlan?.forceBase ?? false) {
                    Button { game.begin(atBase: false) } label: { Text("基地なしではじめる") }
                        .buttonStyle(PuffyStyle(color: .white, height: 50, strong: false))
                } else {
                    Text("夜は、基地に置いてから ねよう").font(.dp(13, .heavy)).foregroundColor(DP.yellow)
                    #if DEBUG
                    if battery == .unknown {
                        Button("（テスト用）基地なしで進む") { game.begin(atBase: false) }.font(.dp(12, .bold)).foregroundColor(DP.dim)
                    }
                    #endif
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(TopGlow(color: Color(hex: 0x6B4A00), reach: 0.5))
        .animation(.spring(response: 0.45, dampingFraction: 0.55), value: placed)
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            withAnimation(.easeInOut(duration: 1.4).repeatForever()) { glow = true }
            check()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)) { _ in check() }
    }

    private var bubbleText: String {
        placed ? "ありがと！ここで まってるね" : "いちばん遠い充電器につないでね"
    }

    private func check() {
        battery = UIDevice.current.batteryState
        guard !placed, battery == .charging || battery == .full else { return }
        placed = true
        if game.pendingPlan?.forceBase ?? false { game.nightBaseKey = NightLock.nightKey() }
        Haptic.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if game.flow == .base { game.begin(atBase: true) }
        }
    }
}

// MARK: - 取り戻し中

struct SessionRunView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var life: LifeState
    @State private var showBreath = false
    @State private var showDM = false
    @State private var askEnd = false
    @State private var quit = false
    @State private var demoTaps = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            let e = game.elapsed(at: tl.date)
            content(elapsed: e, now: tl.date)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in game.tick(now) }
        .background(TopGlow(color: Color(hex: 0x3B2FA0), reach: 0.55))
        .sheet(isPresented: $showBreath) { BreathView(compact: true).environmentObject(game) }
        .sheet(isPresented: $showDM) { InstagramDMView() }
        #if DEBUG
        .onAppear { if UserDefaults.standard.bool(forKey: "debugPeekSheet") { askEnd = true } }
        #endif
    }

    private func content(elapsed e: TimeInterval, now: Date) -> some View {
        let goal = Double(game.sessionGoal * 60)
        let progress = goal > 0 ? min(1, e / goal) : (e.truncatingRemainder(dividingBy: 1800) / 1800)
        let peekLeft = game.peekUntil.map { max(0, $0.timeIntervalSince(now)) }
        let nextBoneMin = 30 - Int(e / 60) % 30

        return VStack(alignment: .leading, spacing: 20) {
            HStack {
                Color.clear.frame(width: 40, height: 40)
                Spacer()
                Text("取り戻し中").font(.dp(15, .bold))
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }

            ZStack {
                DP.purple
                Blob(color: DP.pink.opacity(0.9), size: 240, period: 10).offset(x: -110, y: -110)
                Blob(color: DP.green.opacity(0.85), size: 260, period: 12, offset: 0.5).offset(x: 120, y: 120)
                Blob(color: DP.yellow, size: 90, period: 7, offset: 0.2).offset(x: 100, y: -100)
                if peekLeft != nil {
                    DogView(size: 190, mood: .normal).bob(4, period: 2.4)
                } else {
                    SleepingDog()
                }
                VStack {
                    HStack(spacing: 6) {
                        Circle().fill(DP.green).frame(width: 7, height: 7)
                        Text("LIVE ・ ゆうき、さきも置いてる").font(.dp(11, .heavy))
                    }
                    .padding(.horizontal, 10).frame(height: 26)
                    .background(Capsule().fill(Color.black.opacity(0.35)))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    if game.atBase && peekLeft == nil {
                        HStack(spacing: 5) {
                            Image(systemName: "bolt.fill").font(.system(size: 12, weight: .bold)).foregroundColor(DP.yellow)
                            Text("基地で充電中").font(.dp(12, .heavy))
                        }
                        .padding(.horizontal, 12).frame(height: 30)
                        .background(Capsule().fill(Color.black.opacity(0.35)))
                    }
                    if let left = peekLeft {
                        HStack(spacing: 6) {
                            Image(systemName: "eye.fill").font(.system(size: 12, weight: .bold))
                            Text((game.peekReason.isEmpty ? "中断" : game.peekReason) + " 中… あと").font(.dp(12, .heavy))
                            Text(clock(left)).font(.num(14))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 12).frame(height: 30)
                        .background(Capsule().fill(DP.yellow))
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(14)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: DP.purple.opacity(0.7), radius: 30, y: 20)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(peekLeft != nil ? "中断中" : (AppMode.launch && !game.sessionPurpose.isEmpty ? game.sessionPurpose + "中" : game.sessionTitle)).font(.dp(20, .heavy))
                        .foregroundColor(peekLeft != nil ? DP.yellow : .white)
                    if peekLeft != nil {
                        Text("タイマーは止まってるよ").font(.dp(13, .medium)).foregroundColor(DP.gray)
                    } else if AppMode.launch {
                        Text(game.sessionTitle + " おやすみ中").font(.dp(13, .medium)).foregroundColor(DP.gray)
                    } else {
                    HStack(spacing: 0) {
                        Text("あと\(nextBoneMin)分で ").font(.dp(13, .medium)).foregroundColor(DP.gray)
                        Text("ほね").font(.dp(13, .heavy)).foregroundColor(DP.yellow)
                        Text(" がでるよ").font(.dp(13, .medium)).foregroundColor(DP.gray)
                    }
                    }
                }
                Spacer()
                if !AppMode.launch {
                HStack(spacing: 4) {
                    ForEach(0..<game.maxLives, id: \.self) { i in
                        Image(systemName: i < game.lives ? "heart.fill" : "heart")
                            .foregroundColor(i < game.lives ? DP.pink : Color(hex: 0x3A3A3A))
                    }
                }
                }
            }

            VStack(spacing: 8) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: 0x3A3A3A)).frame(height: 6)
                        Capsule()
                            .fill(LinearGradient(colors: [DP.pink, DP.yellow], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(6, g.size.width * CGFloat(progress)), height: 6)
                            .shadow(color: DP.pink.opacity(0.8), radius: 6)
                        Circle().fill(Color.white).frame(width: 14, height: 14)
                            .offset(x: g.size.width * CGFloat(progress) - 7)
                    }
                    .frame(maxHeight: .infinity)
                    .animation(.easeInOut(duration: 0.9), value: progress)
                }
                .frame(height: 14)
                HStack {
                    Text(clock(e)).font(.num(30))
                        .onTapGesture {
                            // デモ用：タイマーを3回タップで +10分
                            demoTaps += 1
                            if demoTaps % 3 == 0 { game.demoBoost += 600; Haptic.rigid() }
                        }
                    Spacer()
                    Text("ゴール " + clock(goal))
                        .font(.num(13)).foregroundColor(DP.gray)
                }
            }

            Spacer(minLength: 0)

            // DMはOK：ライフも使わず、タイマーも止めない
            Button { Haptic.light(); showDM = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "paperplane.fill").font(.system(size: 13, weight: .bold))
                    Text("DMだけ見る").font(.dp(14, .heavy))
                    Text(AppMode.launch ? "タイマーそのまま" : "ライフそのまま").font(.dp(11, .bold)).foregroundColor(DP.green)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16).frame(height: 40)
                .background(Capsule().fill(Color.white.opacity(0.1)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            }
            .buttonStyle(PressStyle())
            .frame(maxWidth: .infinity)
            .accessibilityLabel(Text("インスタのDMだけ見る。ライフは使わない"))

            HStack(spacing: 12) {
                Button { showBreath = true } label: { CircleIcon(system: "wind", size: 58) }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel(Text("深呼吸"))
                if peekLeft != nil {
                    Button { game.endPeek(); Haptic.success() } label: {
                        Label("もどる", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(PuffyStyle(color: .blue, height: 58))
                } else {
                    peekButton(peeking: false)
                }
            }
            #if DEMO
            Text("デモ版：本番ではここでSNSがロックされるよ")
                .font(.dp(11, .bold)).foregroundColor(DP.yellow.opacity(0.8))
                .frame(maxWidth: .infinity)
            #endif
            Text(footerText(peeking: peekLeft != nil))
                .font(.dp(12, .bold)).foregroundColor(DP.dim)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            if AppMode.launch && peekLeft == nil {
                HoldToEndButton { game.finish() }
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func peekButton(peeking: Bool) -> some View {
        if game.lives > 0 {
            Button { askEnd = true } label: {
                Label(peeking ? "中断中" : (AppMode.launch ? "開きたい" : "中断する（ライフ−1）"), systemImage: "pause.fill")
            }
            .buttonStyle(PuffyStyle(color: .white, height: 58, strong: false))
            .disabled(peeking)
            .opacity(peeking ? 0.5 : 1)
            .sheet(isPresented: $askEnd) {
                if AppMode.launch {
                    PreOpenView(origin: .session).environmentObject(game).environmentObject(life)
                } else {
                    PeekSheet().environmentObject(game)
                        .presentationDetents([.large])
                }
            }
        } else {
            Button { askEnd = true } label: {
                Label("ここまでにする", systemImage: "flag.checkered")
            }
            .buttonStyle(PuffyStyle(color: .yellow, height: 58))
            .alert("ここまで、よくがんばったね", isPresented: $askEnd) {
                Button("おわる") { game.finish() }
                Button("もうすこし つづける", role: .cancel) {}
            } message: {
                Text("取り戻した時間は、ちゃんと記録するよ。")
            }
        }
    }

    private func footerText(peeking: Bool) -> String {
        if peeking { return "\(game.peekMinutes)分たつか「もどる」で、ブロックとタイマーが再開するよ" }
        if AppMode.launch { return "時間になったら、じどうでおわるよ" }
        if game.maxLives == 0 { return "ライフなしモード。⭐ ×" + String(format: "%.1f", rewardMultiplier(lives: game.maxLives, peekMinutes: 0)) }
        if game.lives == 0 { return "ライフがなくなっても大丈夫。ここまでの時間はちゃんと残るよ" }
        return "ゴールの時間になったら、じどうでおわるよ"
    }

    private func clock(_ t: TimeInterval) -> String {
        let s = Int(t)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }
}

/// ねてるドパ抜きちゃん（ゆっくり呼吸＋z）
private struct SleepingDog: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let breath = 1 + 0.04 * sin(t / 6 * 2 * .pi)
            let z = (t / 2.4).truncatingRemainder(dividingBy: 1)
            ZStack {
                DogView(size: 190, mood: .sleep)
                    .scaleEffect(CGFloat(breath))
                Text("z")
                    .font(.dp(28, .black))
                    .foregroundColor(.white)
                    .offset(x: 60 + CGFloat(z) * 12, y: -70 - CGFloat(z) * 26)
                    .opacity(z < 0.3 ? z / 0.3 : 1 - (z - 0.3) / 0.7)
            }
        }
    }
}

// MARK: - 結果

struct ResultView: View {
    @EnvironmentObject var game: GameState
    let result: SessionResult
    @State private var shown: Double = 0
    @State private var appear = false

    var body: some View {
        ZStack {
            TopGlow(color: Color(hex: 0x1E9E5E), reach: 0.6)
            Confetti().ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button { game.closeResult() } label: { CircleIcon(system: "xmark") }
                        .buttonStyle(PressStyle())
                        .accessibilityLabel(Text("とじる"))
                    Spacer()
                }
                Text("クリア ・ \(game.streak)日れんぞく").font(.dp(12, .heavy)).foregroundColor(.white.opacity(0.8))
                VStack(alignment: .leading, spacing: 0) {
                    Text("アルゴリズムから").font(.dp(30, .heavy))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        CountUp(value: shown, font: .num(96), color: DP.yellow)
                        Text("分").font(.dp(30, .heavy))
                    }
                    Text("取り戻した。").font(.dp(30, .heavy))
                }
                HStack(spacing: 8) {
                    Text("GET!").font(.num(14)).foregroundColor(.black)
                        .padding(.horizontal, 10).frame(height: 30)
                        .background(Capsule().fill(DP.yellow))
                    reward("circle.hexagongrid.fill", "+\(result.bones)")
                    reward("star.fill", "+\(result.stars)")
                    if result.multiplier > 1 || result.baseBonus {
                        Text("×" + String(format: "%.1f", result.multiplier * (result.baseBonus ? 1.2 : 1)))
                            .font(.num(15)).foregroundColor(DP.yellow)
                            .fixedSize()
                    }
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)
                if result.baseBonus {
                    Label("基地ボーナス ×1.2", systemImage: "bolt.fill").font(.dp(12, .heavy)).foregroundColor(DP.yellow)
                        .opacity(appear ? 1 : 0)
                }

                if result.declared {
                    let card = ClearCard(name: game.userName.isEmpty ? "わたし" : game.userName, minutes: result.minutes)
                    HStack(spacing: 12) {
                        card.scaleEffect(0.3).frame(width: 96, height: 120)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("宣言どおりクリア！").font(.dp(15, .heavy))
                            Text("\(result.minutes)分 取り戻した").font(.dp(13, .bold)).foregroundColor(DP.gray)
                            ShareLink(item: renderCard(card),
                                      message: Text("宣言どおりクリア！ \(result.minutes)分 取り戻した #ドパ抜きチャレンジ"),
                                      preview: SharePreview("ドパ抜き クリア", image: renderCard(card))) {
                                Label("カードをシェア", systemImage: "square.and.arrow.up").font(.dp(13, .heavy))
                            }
                            .buttonStyle(PuffyStyle(color: .green, height: 36, fullWidth: false, strong: false))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.08)))
                }

                if let t = game.trialGoal {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("「\(t)」どうだった？").font(.dp(15, .heavy))
                        HStack(spacing: 8) {
                            ForEach(Array(["😆 すき", "🙂 ふつう", "🤔 ちがうかも"].enumerated()), id: \.offset) { i, label in
                                Button {
                                    i == 0 ? Haptic.success() : Haptic.light()
                                    withAnimation(.spring()) { game.rateTrial(i) }
                                } label: { Chip(label: label, on: false) }
                                .buttonStyle(PressStyle())
                            }
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.08)))
                    .transition(.opacity)
                }

                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    DogView(size: 170, mood: .happy)
                        .bob(10, period: 0.9)
                    Spacer()
                }
                Spacer(minLength: 0)

                ShareLink(item: "アルゴリズムから\(result.minutes)分 取り戻した！ #ドパ抜きチャレンジ") {
                    Label("ストーリーにシェア", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PuffyStyle(color: .blue, height: 58))
                Button("とじる") { game.closeResult() }
                    .buttonStyle(PuffyStyle(color: .white, height: 54, strong: false))
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).delay(0.3)) { shown = Double(result.minutes) }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(1.2)) { appear = true }
        }
    }

    private func reward(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).foregroundColor(icon == "star.fill" ? DP.yellow : .white)
            Text(text).font(.num(16))
        }
        .fixedSize()
        .padding(.horizontal, 12).frame(height: 30)
        .background(Capsule().fill(Color.white.opacity(0.12)))
    }
}

/// 「おわる」は2秒長押し（リングが一周したら終わる）。ふつうのタップでは終わらない
struct HoldToEndButton: View {
    var onEnd: () -> Void
    @State private var holding = false
    @State private var hint = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.15), lineWidth: 3).frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: holding ? 1 : 0)
                    .stroke(DP.yellow, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 52, height: 52)
                    .animation(holding ? .linear(duration: 2) : .easeOut(duration: 0.2), value: holding)
                Image(systemName: "flag.checkered").font(.system(size: 16, weight: .heavy))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(holding ? 0.2 : 0.1)))
                    .scaleEffect(holding ? 0.92 : 1)
            }
            .onLongPressGesture(minimumDuration: 2, maximumDistance: 40, perform: {
                holding = false
                Haptic.success()
                onEnd()
            }, onPressingChanged: { p in
                holding = p
                if p { Haptic.medium(); hint = false }
            })
            .simultaneousGesture(TapGesture().onEnded { hint = true; Haptic.light() })
            Text(hint ? "長押しで おわる" : "おわる（長押し）").font(.dp(11, .heavy)).foregroundColor(hint ? DP.yellow : DP.gray)
        }
        .accessibilityLabel(Text("2秒長押しで おわる"))
    }
}
