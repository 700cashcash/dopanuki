import SwiftUI

enum LaunchTab: Int, CaseIterable {
    case room, record, breath, friends

    var icon: String { ["house", "square.grid.3x3", "smallcircle.filled.circle", "person.2"][rawValue] }
    var selectedIcon: String { ["house.fill", "square.grid.3x3.fill", "smallcircle.filled.circle.fill", "person.2.fill"][rawValue] }
    var label: String { ["部屋", "記録", "深呼吸", "友達"][rawValue] }
}

/// ローンチ版のいちばん外側：オンボーディング or 4つのタブ
struct LaunchRoot: View {
    @StateObject private var game = GameState()
    @StateObject private var life = LifeState()
    @ObservedObject private var router = Router.shared
    @State private var tab: LaunchTab = .room
    @State private var replayOpening = false
    @State private var chatDone = false
    #if DEBUG
    private var debugBedChat: Bool { UserDefaults.standard.bool(forKey: "debugBedChat") && !chatDone }
    #else
    private let debugBedChat = false
    #endif
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if life.data.onboarded {
                main
            } else {
                OnboardingView()
            }
        }
        .environmentObject(game)
        .environmentObject(life)
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: Binding(get: { game.flow != nil }, set: { if !$0 { game.flow = nil } })) {
            SessionFlowView().environmentObject(game).environmentObject(life)
        }
        .fullScreenCover(isPresented: $replayOpening) {
            OpeningView { replayOpening = false }
        }
        // ブロック画面の「ちょっとだけ開く」→ 通知 → ここ
        .fullScreenCover(isPresented: $router.preOpen) {
            PreOpenView(origin: .shield).environmentObject(game).environmentObject(life)
        }
        .sheet(isPresented: $router.routineAsk) {
            RoutineAskView().environmentObject(life).presentationDetents([.medium])
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                refresh()
                if DMGate.visible { DMGate.open() }      // DMを開いたまま戻ってきた
            } else if phase == .background {
                BowlPlayer.shared.stopAll(fade: 0.3)
                DMGate.close()                           // DMを開いたままアプリを離れたら、遮断をもどす
            }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { game.clock = $0; updateBGM() }
        .onChange(of: game.nightBaseKey) { k in if !k.isEmpty { life.countSleep(nightKey: k) } }
        .onAppear {
            DMGate.close()   // 前回DMを開いたまま落ちていたら、遮断をもどす
            refresh()
            #if DEBUG
            let d = UserDefaults.standard
            if d.object(forKey: "debugTab") != nil, let t = LaunchTab(rawValue: d.integer(forKey: "debugTab")) { tab = t }
            if d.bool(forKey: "debugNoNightBase") { game.nightBaseSkipped = true }
            if d.bool(forKey: "debugPick") && game.flow == nil { game.flow = .pick }
            if d.bool(forKey: "debugRun") && game.flow == nil {
                var p = SessionPlan(title: "25分", goalMinutes: 25, lives: 3, peekMinutes: 5, useBase: false)
                p.purpose = "英単語"
                game.start(p); game.begin(atBase: false)
            }
            if d.bool(forKey: "debugWelcome") {
                game.flow = .result(SessionResult(minutes: d.integer(forKey: "debugWelcomeMin") == 0 ? 40 : d.integer(forKey: "debugWelcomeMin"),
                                                  bones: 0, stars: 0, purpose: "英単語", goal: 40, completed: !d.bool(forKey: "debugQuit")))
            }
            if d.bool(forKey: "debugDeclare") && game.flow == nil {
                var p = SessionPlan(title: "40分", goalMinutes: 40, lives: 3, peekMinutes: 5, useBase: false)
                p.purpose = "英単語"; p.declared = true; p.cardWhen = "21:30まで"
                game.start(p)
            }
            if d.bool(forKey: "debugIcon") { IconExport.run() }
            if d.bool(forKey: "debugPreOpen") { router.preOpen = true }
            if d.bool(forKey: "debugMilestone") { life.pendingMilestone = 600 }
            #endif
        }
    }

    /// 寝る前のおしゃべり（ロックON/OFFどちらでも、ねる30分前から1回）
    private var showBedChat: Bool {
        if debugBedChat { return true }
        guard !chatDone, life.data.planDay != LifeState.today(), NightLock.isBedWindow(game.clock) else { return false }
        let key = NightLock.nightKey(game.clock)
        guard game.nightBaseKey != key, life.data.sleepKey != key else { return false }
        return NightLock.isOn ? game.needsNightBase : true
    }

    private var main: some View {
        Group {
            switch tab {
            case .room: LaunchRoomView()
            case .record: LaunchRecordView(replayOpening: $replayOpening)
            case .breath: BreathView()
            case .friends: LaunchFriendsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) { LaunchTabBar(tab: $tab) }
        .background(DP.bg.ignoresSafeArea())
        // おやすみ：寝る前のおしゃべり → 基地につなぐまで すすめない
        .overlay {
            if showBedChat {
                BedtimeChatView(lockOn: NightLock.isOn) {
                    chatDone = true
                    // おやすみロックOFF：ロックなしで部屋を消灯するだけ
                    if !NightLock.isOn { life.data.sleepKey = NightLock.nightKey(game.clock) }
                }
                .transition(.opacity)
            } else if game.needsNightBase {
                NightBaseView().environmentObject(game).transition(.opacity)
            }
        }
    }

    /// BGM：おやすみロック中（部屋が消灯）は止める
    private func updateBGM() {
        let locked = NightLock.isSleepTime(game.clock) && game.nightBaseKey == NightLock.nightKey(game.clock)
        if locked {
            if BowlPlayer.shared.mode == .ambient { BowlPlayer.shared.stopAll(fade: 3) }
        } else if BowlPlayer.shared.mode == .off {
            BowlPlayer.shared.startAmbient()
        }
    }

    private func refresh() {
        defer { updateBGM() }
        game.checkNight()
        Schedules.apply()
        // 毎日いっしょに置く時間がおわっていたら、おかえり
        if game.flow == nil, let r = Schedules.takeRoutineDone(), r.minutes > 0 {
            game.flow = .result(SessionResult(minutes: r.minutes, bones: 0, stars: 0, purpose: r.purpose, goal: r.minutes, completed: true))
        }
        game.nightToast = nil   // ローンチ版は朝のあいさつで伝える
        game.clock = Date()
        life.weekCardIfNeeded()
    }
}

struct LaunchTabBar: View {
    @Binding var tab: LaunchTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LaunchTab.allCases, id: \.self) { t in
                Button {
                    if tab != t { Haptic.select() }
                    tab = t
                } label: {
                    Image(systemName: tab == t ? t.selectedIcon : t.icon)
                        .font(.system(size: 23, weight: tab == t ? .bold : .regular))
                        .foregroundColor(tab == t ? .white : Color(hex: 0xA8A8A8))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle(scale: 0.86))
                .accessibilityLabel(Text(t.label))
            }
        }
        .padding(.horizontal, 8)
        .background(Color.black.ignoresSafeArea(edges: .bottom))
        .overlay(Rectangle().fill(DP.line).frame(height: 1), alignment: .top)
    }
}

// MARK: - 友達（軽い版：さそう・DMだけ）

struct LaunchFriendsView: View {
    @EnvironmentObject var game: GameState
    @State private var showDM = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("友達").font(.dp(28, .heavy)).padding(.top, 52)
            HStack(spacing: 12) {
                DogView(size: 90, mood: .happy, alive: true)
                Bubble(text: "友達といっしょだと、置けるよ")
            }
            ShareLink(item: ShareInfo.invite) {
                Label("友達をさそう", systemImage: "person.badge.plus")
            }
            .buttonStyle(PuffyStyle(color: .green, height: 60))
            Button { Haptic.light(); showDM = true } label: {
                Label("インスタのDMだけ開く", systemImage: "paperplane.fill")
            }
            .buttonStyle(PuffyStyle(color: .white, height: 56, strong: false))
            Text("DMはブラウザ版で開くよ。リールは出ない・初回だけログイン").font(.dp(12, .bold)).foregroundColor(DP.dim)
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(TopGlow(color: Color(hex: 0x1E9E5E).opacity(0.6), reach: 0.35))
        .sheet(isPresented: $showDM) { InstagramDMView() }
    }
}

// MARK: - 設定（歯車）

struct LaunchSettingsView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var life: LifeState
    @Environment(\.dismiss) private var dismiss
    @State private var showApps = false
    @State private var showDM = false
    @State private var bed = SharedSettings.nightStartHour
    @State private var wake = SharedSettings.nightEndHour
    @State private var devTaps = 0
    @State private var bgm = BowlPlayer.shared.bgmEnabled
    @State private var nightLock = SharedSettings.nightBlockEnabled
    @State private var goalOn = SharedSettings.goalEnabled
    @State private var goalMin = SharedSettings.goalMinutes
    @State private var routineOn = SharedSettings.routineEnabled
    @State private var rStart = SharedSettings.routineStartHour
    @State private var rEnd = SharedSettings.routineEndHour
    @State private var rDays = SharedSettings.routineWeekdays

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button { dismiss() } label: { CircleIcon(system: "xmark") }.buttonStyle(PressStyle())
                    Spacer()
                }
                Text("設定").font(.dp(28, .heavy))

                section("時間を食べるアプリ") {
                    Button { showApps = true } label: {
                        row(icon: "app.badge.fill", title: "えらぶ・許可する",
                            sub: NightLock.hasTargets ? "えらんである" : "まだ えらんでないよ")
                    }
                    .buttonStyle(PressStyle(scale: 0.97))
                }

                section("おやすみロック") {
                    Toggle(isOn: Binding(get: { nightLock }, set: { v in
                        nightLock = v
                        SharedSettings.nightBlockEnabled = v
                        if !v { Blocker.unblock(.nightBlock) }
                        UserDefaults.standard.removeObject(forKey: "p.nightEvents")
                        NightLock.apply()
                        Haptic.select()
                    })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("夜はSNSをロック").font(.dp(15, .heavy))
                            Text(nightLock ? "ねる前に基地（充電）につなぐよ" : "OFF：ロックも基地もなし。部屋が消灯するだけ")
                                .font(.dp(12, .bold)).foregroundColor(DP.gray)
                        }
                    }
                    .tint(DP.violet)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
                }

                section("寝る時間") {
                    HStack(spacing: 10) {
                        hourBox("ねる", $bed)
                        Image(systemName: "arrow.right").foregroundColor(DP.gray)
                        hourBox("おきる", $wake)
                    }
                    .onChange(of: bed) { _ in saveBed() }
                    .onChange(of: wake) { _ in saveBed() }
                }

                section("なまえ") {
                    field("ドパ抜きちゃんの なまえ", $game.dogName)
                    field("カードに出る自分の なまえ", $game.userName)
                }

                if Features.soundEnabled {
                section("音") {
                    Toggle(isOn: Binding(get: { bgm }, set: { bgm = $0; BowlPlayer.shared.bgmEnabled = $0; Haptic.select() })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("BGM（クリスタルボウル）").font(.dp(15, .heavy))
                            Text("マナーモードのときは鳴らないよ").font(.dp(12, .bold)).foregroundColor(DP.gray)
                        }
                    }
                    .tint(DP.violet)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
                }
                }

                section("インスタ") {
                    Button { showDM = true } label: { row(icon: "paperplane.fill", title: "DMだけ開く", sub: "リールは出ないブラウザ版") }
                        .buttonStyle(PressStyle(scale: 0.97))
                }

                section("1日の目標") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: Binding(get: { goalOn }, set: { goalOn = $0; SharedSettings.goalEnabled = $0; Schedules.reset() })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("時間を食べるアプリは 1日").font(.dp(15, .heavy))
                                Text("目標をこえたら、きょうはブロック").font(.dp(12, .bold)).foregroundColor(DP.gray)
                            }
                        }
                        .tint(DP.violet)
                        if goalOn {
                            FlowChips(items: GoalChoice.labels, selected: GoalChoice.label(goalMin)) { l in
                                goalMin = GoalChoice.minutes(l) ?? goalMin
                                SharedSettings.goalMinutes = goalMin
                                Schedules.reset()
                            }
                            Stepper("\(GoalChoice.label(goalMin))まで", value: Binding(get: { goalMin }, set: {
                                goalMin = $0; SharedSettings.goalMinutes = $0; Schedules.reset()
                            }), in: 10...300, step: 10)
                            .font(.dp(14, .heavy))
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
                }

                section("毎日いっしょに置く時間") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: Binding(get: { routineOn }, set: { routineOn = $0; SharedSettings.routineEnabled = $0; Schedules.reset() })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("自動でスマホを置く").font(.dp(15, .heavy))
                                Text("時間になったらブロック＋お知らせ（夜がかさなったら夜を優先）").font(.dp(12, .bold)).foregroundColor(DP.gray)
                            }
                        }
                        .tint(DP.violet)
                        if routineOn {
                            HStack(spacing: 10) {
                                hourBox("はじめ", Binding(get: { rStart }, set: { rStart = $0; SharedSettings.routineStartHour = $0; Schedules.reset() }))
                                Image(systemName: "arrow.right").foregroundColor(DP.gray)
                                hourBox("おわり", Binding(get: { rEnd }, set: { rEnd = $0; SharedSettings.routineEndHour = $0; Schedules.reset() }))
                            }
                            HStack(spacing: 6) {
                                ForEach(1...7, id: \.self) { wd in
                                    let on = rDays.contains(wd)
                                    Button {
                                        if on { rDays.removeAll { $0 == wd } } else { rDays.append(wd) }
                                        SharedSettings.routineWeekdays = rDays.sorted()
                                        Schedules.reset()
                                        Haptic.select()
                                    } label: {
                                        Text(["日", "月", "火", "水", "木", "金", "土"][wd - 1]).font(.dp(13, .heavy))
                                            .foregroundColor(on ? .black : .white)
                                            .frame(width: 36, height: 36)
                                            .background(Circle().fill(on ? Color.white : DP.card2))
                                    }
                                    .buttonStyle(PressStyle())
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
                }

                section("応援する") {
                    TipJarCard()
                }

                Text("ドパ抜き 1.0")
                    .font(.dp(11, .bold)).foregroundColor(DP.dim)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    .onTapGesture { devTaps += 1 }

                if devTaps >= 5 {
                    section("開発用") {
                        Text("キモさプレビュー").font(.dp(13, .heavy))
                        Picker("キモさ", selection: $life.data.kimoPreview) {
                            Text("本物").tag(-1)
                            ForEach(0...4, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Button("「ねえねえ」と朝のあいさつを リセット") {
                            life.data.neeneeDay = ""; life.data.morningAskedDay = ""; life.data.morningShownDay = ""; life.data.quizDay = ""
                            Haptic.success()
                        }
                        .font(.dp(13, .bold))
                    }
                }
            }
            .padding(20)
        }
        .background(DP.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showApps) { BlockSettingsView() }
        .sheet(isPresented: $showDM) { InstagramDMView() }
        .onAppear {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "debugDev") { devTaps = 5 }
            #endif
        }
    }

    private func saveBed() {
        SharedSettings.nightStartHour = bed
        SharedSettings.nightEndHour = wake
        UserDefaults.standard.removeObject(forKey: "p.nightEvents")
        NightLock.apply()
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.dp(12, .heavy)).foregroundColor(DP.gray)
            content()
        }
    }

    private func row(icon: String, title: String, sub: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundColor(DP.pink).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.dp(15, .heavy)).foregroundColor(.white)
                Text(sub).font(.dp(12, .bold)).foregroundColor(DP.gray)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(DP.dim)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
    }

    private func field(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.dp(11, .bold)).foregroundColor(DP.dim)
            TextField(label, text: text).font(.dp(16, .heavy))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
    }

    private func hourBox(_ label: String, _ hour: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.dp(12, .heavy)).foregroundColor(DP.gray)
            Picker(label, selection: hour) {
                ForEach(0..<24, id: \.self) { h in Text(String(format: "%d:00", h)).tag(h) }
            }
            .pickerStyle(.menu).tint(.white)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
    }
}

// MARK: - 寝る前のおしゃべり（できたこと → あした → ねかせる）

struct BedtimeChatView: View {
    @EnvironmentObject var life: LifeState
    var lockOn = true
    var onDone: () -> Void
    @State private var step = 0
    @State private var done = ""
    @State private var tomorrow = ""

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x10163A), DP.bg], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Text("ねる前に").font(.dp(28, .heavy))
                HStack {
                    Spacer()
                    DogView(size: 150, mood: step == 2 ? .happy : .sleep, pose: DogPose(headTilt: step == 2 ? 0 : 6), alive: true)
                    Spacer()
                }
                switch step {
                case 0:
                    Bubble(text: "ねえねえ…きょうできたこと、ひとつ教えて")
                    answer(text: $done, placeholder: "例：英単語40こ") { step = 1 }
                case 1:
                    Bubble(text: "あしたは 何したい？")
                    FlowChips(items: life.purposes, selected: tomorrow) { tomorrow = $0 }
                    answer(text: $tomorrow, placeholder: "ほかに書く") { step = 2 }
                default:
                    Bubble(text: done.isEmpty ? "きょうも おつかれさま。えらかったね" : "「\(done)」できたの、えらすぎ")
                    Spacer(minLength: 0)
                    Button {
                        life.saveNight(done: done, tomorrow: tomorrow)
                        Haptic.success()
                        onDone()
                    } label: { Label(lockOn ? "ねかせる" : "おやすみ", systemImage: "moon.zzz.fill") }
                        .buttonStyle(PuffyStyle(color: .purple, height: 58))
                }
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
    }

    private func answer(text: Binding<String>, placeholder: String, next: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            TextField(placeholder, text: text)
                .font(.dp(16, .heavy))
                .padding(.horizontal, 14).frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(DP.card))
            Spacer(minLength: 0)
            Button { Haptic.select(); next() } label: { Text(text.wrappedValue.isEmpty ? "とばす" : "つぎへ") }
                .buttonStyle(PuffyStyle(color: text.wrappedValue.isEmpty ? .white : .blue, height: 54, strong: !text.wrappedValue.isEmpty))
        }
    }
}

/// 1日の目標のえらびかた
enum GoalChoice {
    static let labels = ["30分", "1時間", "1.5時間", "2時間"]
    static func minutes(_ l: String) -> Int? { ["30分": 30, "1時間": 60, "1.5時間": 90, "2時間": 120][l] }
    static func label(_ m: Int) -> String {
        if m % 60 == 0 { return "\(m / 60)時間" }
        if m > 60 && m % 30 == 0 { return String(format: "%.1f時間", Double(m) / 60) }
        return m > 60 ? "\(m / 60)時間\(m % 60)分" : "\(m)分"
    }
}
