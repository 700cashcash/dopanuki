import SwiftUI
import DeviceActivity
import UserNotifications

/// 1日の目標（時間を食べるアプリは1日どれくらいまで）と、毎日いっしょに置く時間のスケジュール
enum Schedules {
    /// アプリを開くたびに呼ぶ（同じ設定なら登録しなおさない）
    static func apply() {
        #if DEMO
        return
        #else
        guard NightLock.isReady else { return }
        applyGoal()
        applyRoutine()
        Shields.restore()
        #endif
    }

    /// 設定を変えたら、次の apply で登録しなおす
    static func reset() {
        UserDefaults.standard.removeObject(forKey: "p.goalVer")
        UserDefaults.standard.removeObject(forKey: "p.routineVer")
        apply()
    }

    private static func applyGoal() {
        let center = DeviceActivityCenter()
        let goal = SharedSettings.goalMinutes
        let ver = "g1-\(SharedSettings.goalEnabled)-\(goal)"
        guard UserDefaults.standard.string(forKey: "p.goalVer") != ver || center.schedule(for: .daily) == nil else { return }
        center.stopMonitoring([.daily])
        Blocker.unblock(.dailyLimit)
        guard SharedSettings.goalEnabled else { UserDefaults.standard.set(ver, forKey: "p.goalVer"); return }
        let s = SharedSettings.selection
        func ev(_ m: Int) -> DeviceActivityEvent {
            DeviceActivityEvent(applications: s.applicationTokens, categories: s.categoryTokens, webDomains: s.webDomainTokens,
                                threshold: DateComponents(minute: m))
        }
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [.goalReached: ev(goal)]
        if goal >= 10 { events[.goalHalf] = ev(goal / 2) }
        if goal > 15 { events[.goalLeft10] = ev(goal - 10) }
        // 部屋の「きょう 30分 / 1時間」用（5分きざみ）
        for m in stride(from: 5, to: goal, by: 5) { events[.goalUsage(m)] = ev(m) }
        let day = DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0),
                                         intervalEnd: DateComponents(hour: 23, minute: 59), repeats: true)
        do {
            try center.startMonitoring(.daily, during: day, events: events)
            UserDefaults.standard.set(ver, forKey: "p.goalVer")
        } catch { print("goal:", error) }
    }

    private static func applyRoutine() {
        let center = DeviceActivityCenter()
        let days = SharedSettings.routineWeekdays.sorted()
        let st = SharedSettings.routineStartHour, en = SharedSettings.routineEndHour
        let ver = "r1-\(SharedSettings.routineEnabled)-\(st)-\(en)-\(days)"
        guard UserDefaults.standard.string(forKey: "p.routineVer") != ver else { return }
        center.stopMonitoring((0...7).map { DeviceActivityName.routine($0) })
        Blocker.unblock(.routine)
        UserDefaults.standard.set(ver, forKey: "p.routineVer")
        guard SharedSettings.routineEnabled, st != en, !days.isEmpty else { return }
        if days.count == 7 {
            try? center.startMonitoring(.routine(0), during: DeviceActivitySchedule(
                intervalStart: DateComponents(hour: st, minute: 0), intervalEnd: DateComponents(hour: en, minute: 0), repeats: true))
        } else {
            for wd in days {
                try? center.startMonitoring(.routine(wd), during: DeviceActivitySchedule(
                    intervalStart: DateComponents(hour: st, minute: 0, weekday: wd),
                    intervalEnd: DateComponents(hour: en, minute: 0, weekday: wd), repeats: true))
            }
        }
    }

    /// 毎日いっしょに置く時間がおわっていたら（拡張が記録）、その時間を返して消す
    static func takeRoutineDone() -> (minutes: Int, purpose: String)? {
        let d = SharedSettings.defaults
        guard let raw = d.string(forKey: "routineDone") else { return nil }
        d.removeObject(forKey: "routineDone")
        let parts = raw.split(separator: "|").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        let purpose = d.string(forKey: "routinePurpose") ?? ""
        d.removeObject(forKey: "routinePurpose")
        return (max(0, Int((parts[1] - parts[0]) / 60)), purpose)
    }

    static func askNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}

/// 通知をタップしてアプリが開いたときの行き先
final class Router: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = Router()
    /// ブロック画面の「ちょっとだけ開く」から：ひと呼吸 → 目的 → 何分
    @Published var preOpen = false
    /// 毎日いっしょに置く時間が始まった：何する？（答えなくてもOK）
    @Published var routineAsk = false

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler done: @escaping () -> Void) {
        let kind = response.notification.request.content.userInfo["kind"] as? String
        DispatchQueue.main.async {
            if kind == "preopen" { self.preOpen = true }
            if kind == "routine" { self.routineAsk = true }
        }
        done()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
        done([.banner, .sound])
    }
}

// MARK: - 開く前：5秒の深呼吸 → 目的（必須）→ 何分

struct PreOpenView: View {
    enum Origin { case shield, session }
    let origin: Origin
    @EnvironmentObject var game: GameState
    @EnvironmentObject var life: LifeState
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0           // 0 深呼吸, 1 目的, 2 何分
    @State private var breathStart = Date()
    @State private var purpose = ""
    @State private var custom = ""
    @State private var minutes = 5
    @State private var lastTick = -1

    private let reasons = ["LINEの返信", "連絡・電話", "調べもの", "地図・乗りかえ", "写真", "そのほか"]
    private let lengths = [1, 3, 5, 10, 15, 30, 60]
    /// どのライフを使うか（セッション・1日の目標・毎日の時間）
    private var ctx: Shields.LifeContext? {
        if game.sessionStart != nil { return .session }
        return Shields.context()
    }
    private var livesLeft: Int {
        guard let c = ctx else { return 3 }
        return c == .session ? game.lives : Shields.lives(c)
    }

    /// ライフ0：「ちょっとだけ開く」はなし。ここまでにする
    private var outOfLives: some View {
        VStack(spacing: 18) {
            Spacer()
            DogView(size: 150, mood: .normal, pose: DogPose(headTilt: -6), alive: true)
            Bubble(text: "ライフがもうないよ。きょうは ここまでにしよ？")
            Text("ここまでの時間は、ちゃんと残るよ").font(.dp(13, .bold)).foregroundColor(DP.gray)
            Spacer()
            Button {
                Haptic.success()
                if ctx == .session { game.finish() }
                dismiss()
            } label: { Text("ここまでにする") }
                .buttonStyle(PuffyStyle(color: .yellow, height: 56))
            Button("もうすこし がんばる") { dismiss() }
                .font(.dp(14, .heavy)).foregroundColor(DP.gray)
        }
        .padding(24)
    }

    private var hearts: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < livesLeft ? "heart.fill" : "heart.slash")
                    .foregroundColor(i < livesLeft ? DP.pink : DP.dim)
            }
        }
    }

    private var chosen: String {
        let c = custom.trimmingCharacters(in: .whitespaces)
        return c.isEmpty ? (purpose == "そのほか" ? "" : purpose) : c
    }

    var body: some View {
        ZStack {
            DP.bg.ignoresSafeArea()
            TopGlow(color: DP.purple.opacity(0.6), reach: 0.5)
            if livesLeft == 0 {
                outOfLives
            } else {
                switch step {
                case 0: breath
                default: form
                }
            }
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
        .interactiveDismissDisabled(step == 0)
    }

    // 5秒：すって3秒・はいて2秒（スキップなし）
    private var breath: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { tl in
            let t = tl.date.timeIntervalSince(breathStart)
            let inhale = t < 3
            let full = inhale ? (1 - cos(min(t, 3) / 3 * .pi)) / 2 : 1 - (1 - cos(min(t - 3, 2) / 2 * .pi)) / 2
            VStack(spacing: 24) {
                Text("ひと呼吸してから").font(.dp(24, .heavy)).padding(.top, 60)
                Spacer()
                ZStack {
                    Circle().fill(Color.white.opacity(0.1))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 2))
                        .frame(width: 260, height: 260)
                        .scaleEffect(CGFloat(0.7 + 0.3 * full))
                    VStack(spacing: 6) {
                        DogView(size: 100, mood: .sleep)
                        Text(inhale ? "すって…" : "はいて…").font(.dp(18, .heavy))
                        Text("\(max(1, 5 - Int(t)))").font(.num(28)).foregroundColor(DP.yellow)
                    }
                }
                Spacer()
                Text("あと少し").font(.dp(13, .bold)).foregroundColor(DP.gray).padding(.bottom, 40)
            }
            .onChange(of: Int(t * 4)) { q in
                guard q != lastTick else { return }
                lastTick = q
                if t >= 5 { withAnimation { step = 1 }; Haptic.success(); return }
                if inhale { Haptic.soft(CGFloat(0.3 + 0.7 * full)) } else if q % 2 == 0 { Haptic.soft(CGFloat(max(0.2, full))) }
            }
        }
        .onAppear { breathStart = Date() }
    }

    private var form: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button { dismiss() } label: { CircleIcon(system: "xmark") }.buttonStyle(PressStyle())
                    Spacer()
                    hearts
                }
                HStack(spacing: 10) {
                    DogView(size: 64, mood: .normal, alive: true)
                    Bubble(text: "何しに開く？")
                }
                FlowChips(items: reasons, selected: purpose) { p in Haptic.select(); purpose = p; if p != "そのほか" { custom = "" } }
                TextField("ほかに書く", text: $custom)
                    .font(.dp(15, .bold))
                    .padding(.horizontal, 14).frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(DP.card))
                Text("何分？").font(.dp(16, .heavy))
                FlowChips(items: lengths.map { "\($0)分" }, selected: "\(minutes)分") { m in
                    Haptic.select(); minutes = Int(m.dropLast()) ?? 5
                }
                Text("時間になったら、またブロックにもどるよ").font(.dp(12, .bold)).foregroundColor(DP.dim)
                Button(action: open) {
                    Label(chosen.isEmpty ? "何しに開くか えらんでね" : "\(minutes)分だけ開く（ライフ−1）", systemImage: "lock.open.fill")
                }
                .buttonStyle(PuffyStyle(color: .white, height: 56, strong: false))
                .disabled(chosen.isEmpty)
                .opacity(chosen.isEmpty ? 0.5 : 1)
                Button("やっぱり やめとく") { Haptic.success(); dismiss() }
                    .font(.dp(14, .heavy)).foregroundColor(DP.gray).frame(maxWidth: .infinity)
            }
            .padding(20)
        }
    }

    private func open() {
        life.data.opens.append(OpenLog(purpose: chosen, minutes: minutes))
        Haptic.soft(0.7)   // ハートが割れる（責めない）
        if game.sessionStart != nil && game.peekUntil == nil {
            game.peek(minutes: minutes, reason: chosen)      // セッションのタイマーは止まる・ライフ−1
        } else if let c = ctx, c != .session {
            Shields.useLife(c)                               // 1日の目標・毎日の時間のライフ−1
        }
        #if !DEMO
        Shields.unlock(minutes: minutes)                     // 夜・目標・毎日の時間のブロックも外す（あとで戻す）
        #endif
        Haptic.medium()
        dismiss()
    }
}

/// 毎日いっしょに置く時間：何する？（スキップOK）
struct RoutineAskView: View {
    @EnvironmentObject var life: LifeState
    @Environment(\.dismiss) private var dismiss
    @State private var purpose = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                DogView(size: 80, mood: .happy, alive: true)
                Bubble(text: "いっしょに置く時間だよ。何する？")
            }
            FlowChips(items: life.purposes, selected: purpose) { purpose = $0; Haptic.select() }
            Spacer()
            Button {
                SharedSettings.defaults.set(purpose, forKey: "routinePurpose")
                if !purpose.isEmpty { life.setTodayGoal(purpose) }
                Haptic.success()
                dismiss()
            } label: { Text(purpose.isEmpty ? "とばす" : "\(purpose)する！") }
                .buttonStyle(PuffyStyle(color: purpose.isEmpty ? .white : .blue, height: 56, strong: !purpose.isEmpty))
        }
        .padding(22)
        .background(DP.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
