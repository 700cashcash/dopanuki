import SwiftUI
import FamilyControls
import ManagedSettings

struct Goal: Identifiable, Codable, Equatable {
    var id = UUID()
    var emoji: String
    var title: String
    var done: Bool
    var fav = false      // 5分やってみて「すき」だった

    init(emoji: String, title: String, done: Bool, fav: Bool = false) {
        self.emoji = emoji; self.title = title; self.done = done; self.fav = fav
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        emoji = try c.decode(String.self, forKey: .emoji)
        title = try c.decode(String.self, forKey: .title)
        done = try c.decode(Bool.self, forKey: .done)
        fav = try c.decodeIfPresent(Bool.self, forKey: .fav) ?? false
    }
}

struct SessionPlan: Equatable {
    var title: String
    var goalMinutes: Int
    var lives: Int = 3        // 0〜3
    var peekMinutes: Int = 5  // 1回の中断の分数（1〜60）
    var useBase = true        // 基地スタート（充電器に置いてから はじめる）
}

/// ライフが少ないほど、ちょっとだけタイムが短いほど ⭐ がふえる
func rewardMultiplier(lives: Int, peekMinutes: Int) -> Double {
    let base: [Double] = [2.0, 1.5, 1.2, 1.0]
    let b = base[min(max(lives, 0), 3)]
    let penalty: Double
    switch peekMinutes {
    case ...5: penalty = 0
    case ...15: penalty = 0.1
    case ...30: penalty = 0.2
    default: penalty = 0.3
    }
    return max(1.0, b - penalty)
}

struct SessionResult: Equatable {
    var minutes: Int
    var bones: Int
    var stars: Int
    var multiplier: Double = 1
    var baseBonus = false
}

enum SessionFlow: Equatable {
    case pick
    case base        // スマホ基地に置く
    case running
    case result(SessionResult)
}

/// プロトタイプの状態（UserDefaults に保存。アプリを消すまで残る）
final class GameState: ObservableObject {
    private static let ud = UserDefaults.standard

    @Published var dogName: String { didSet { Self.ud.set(dogName, forKey: "p.dogName") } }
    @Published var stars: Int { didSet { Self.ud.set(stars, forKey: "p.stars") } }
    @Published var bones: Int { didSet { Self.ud.set(bones, forKey: "p.bones") } }
    @Published var streak: Int { didSet { Self.ud.set(streak, forKey: "p.streak") } }
    @Published var totalMinutes: Int { didSet { Self.ud.set(totalMinutes, forKey: "p.total") } }
    @Published var todayMinutes: Int { didSet { Self.ud.set(todayMinutes, forKey: "p.today") } }
    @Published var yesterdayMinutes: Int { didSet { Self.ud.set(yesterdayMinutes, forKey: "p.yesterday") } }
    @Published var weekMinutes: Int { didSet { Self.ud.set(weekMinutes, forKey: "p.week") } }
    @Published var lastDay: String { didSet { Self.ud.set(lastDay, forKey: "p.lastDay") } }
    @Published var lastSessionDay: String { didSet { Self.ud.set(lastSessionDay, forKey: "p.lastSessionDay") } }
    @Published var goals: [Goal] { didSet { Self.ud.set(try? JSONEncoder().encode(goals), forKey: "p.goals") } }
    @Published var items: [String] { didSet { Self.ud.set(items, forKey: "p.items") } }

    // セッション（アプリを閉じても続く）
    @Published var sessionStart: Date? { didSet { Self.ud.set(sessionStart?.timeIntervalSince1970, forKey: "p.sStart") } }
    @Published var sessionTitle: String { didSet { Self.ud.set(sessionTitle, forKey: "p.sTitle") } }
    @Published var sessionGoal: Int { didSet { Self.ud.set(sessionGoal, forKey: "p.sGoal") } }
    @Published var demoBoost: Double = 0   // デモ用：タイマーを進める秒数
    @Published var lives: Int { didSet { Self.ud.set(lives, forKey: "p.lives") } }
    /// 中断（ライフ−1）で、ブロックを止めている終わりの時刻
    @Published var peekUntil: Date? { didSet { Self.ud.set(peekUntil?.timeIntervalSince1970, forKey: "p.peek") } }
    /// 中断中はタイマーを止める（止めていた合計秒・いまの中断の開始）
    @Published var pausedTotal: Double { didSet { Self.ud.set(pausedTotal, forKey: "p.paused") } }
    @Published var peekStart: Date? { didSet { Self.ud.set(peekStart?.timeIntervalSince1970, forKey: "p.peekStart") } }
    @Published var maxLives: Int { didSet { Self.ud.set(maxLives, forKey: "p.maxLives") } }
    @Published var peekMinutes: Int { didSet { Self.ud.set(peekMinutes, forKey: "p.peekMin") } }
    @Published var worry: String { didSet { Self.ud.set(worry, forKey: "p.worry") } }

    @Published var flow: SessionFlow?
    /// 基地に置く画面で待っているプラン
    @Published var pendingPlan: SessionPlan?
    @Published var atBase: Bool { didSet { Self.ud.set(atBase, forKey: "p.atBase") } }
    @Published var useBase: Bool { didSet { Self.ud.set(useBase, forKey: "p.useBase") } }
    /// いいねしたレッスンカード（"コースID-問題番号"）
    @Published var likedCards: [String] { didSet { Self.ud.set(likedCards, forKey: "p.liked") } }
    /// 深呼吸した合計分数（ごほうびの道）
    @Published var breathMinutes: Int { didSet { Self.ud.set(breathMinutes, forKey: "p.breathMin") } }
    /// なにをやったかの記録（"goal:タイトル" "fav:タイトル" "lesson:コース" "alt:タイトル" → 回数）
    @Published var activity: [String: Int] { didSet { Self.ud.set(activity, forKey: "p.activity") } }
    /// 「5分だけやってみる」中のやりたいこと（おわったら どうだった？ を聞く）
    @Published var trialGoal: String? { didSet { Self.ud.set(trialGoal, forKey: "p.trial") } }
    @Published var bgm: String { didSet { Self.ud.set(bgm, forKey: "p.bgm") } }
    /// けさ、おやすみロックで取り戻した分（トースト用）
    @Published var nightToast: Int?

    init() {
        let d = UserDefaults.standard
        dogName = d.string(forKey: "p.dogName") ?? "ドパ抜きちゃん"
        stars = d.object(forKey: "p.stars") as? Int ?? 1240
        bones = d.object(forKey: "p.bones") as? Int ?? 3
        streak = d.object(forKey: "p.streak") as? Int ?? 4
        totalMinutes = d.object(forKey: "p.total") as? Int ?? 18 * 60
        todayMinutes = d.object(forKey: "p.today") as? Int ?? 0
        yesterdayMinutes = d.object(forKey: "p.yesterday") as? Int ?? 74
        weekMinutes = d.object(forKey: "p.week") as? Int ?? 9 * 60 + 40
        lastDay = d.string(forKey: "p.lastDay") ?? GameState.dayKey(Date())
        lastSessionDay = d.string(forKey: "p.lastSessionDay") ?? GameState.dayKey(Date().addingTimeInterval(-86400))
        if let data = d.data(forKey: "p.goals"), let g = try? JSONDecoder().decode([Goal].self, from: data) {
            goals = g
        } else {
            goals = [
                Goal(emoji: "🌅", title: "早起き", done: true),
                Goal(emoji: "📚", title: "本を月1冊", done: true),
                Goal(emoji: "🗣️", title: "英語を話す", done: false),
                Goal(emoji: "💪", title: "筋トレ", done: false),
                Goal(emoji: "🍳", title: "料理", done: false),
                Goal(emoji: "✈️", title: "ひとり旅", done: false),
            ]
        }
        items = d.stringArray(forKey: "p.items") ?? []
        if let s = d.object(forKey: "p.sStart") as? Double {
            sessionStart = Date(timeIntervalSince1970: s)
        } else {
            sessionStart = nil
        }
        sessionTitle = d.string(forKey: "p.sTitle") ?? "ちょっとだけ"
        sessionGoal = d.object(forKey: "p.sGoal") as? Int ?? 25
        lives = d.object(forKey: "p.lives") as? Int ?? 3
        peekUntil = (d.object(forKey: "p.peek") as? Double).map { Date(timeIntervalSince1970: $0) }
        pausedTotal = d.double(forKey: "p.paused")
        peekStart = (d.object(forKey: "p.peekStart") as? Double).map { Date(timeIntervalSince1970: $0) }
        maxLives = d.object(forKey: "p.maxLives") as? Int ?? 3
        peekMinutes = d.object(forKey: "p.peekMin") as? Int ?? 5
        worry = d.string(forKey: "p.worry") ?? ""
        atBase = d.bool(forKey: "p.atBase")
        useBase = d.object(forKey: "p.useBase") as? Bool ?? true
        likedCards = d.stringArray(forKey: "p.liked") ?? []
        breathMinutes = d.integer(forKey: "p.breathMin")
        bgm = d.string(forKey: "p.bgm") ?? "none"
        activity = d.dictionary(forKey: "p.activity") as? [String: Int] ?? [:]
        trialGoal = d.string(forKey: "p.trial")
        if sessionStart != nil { flow = .running }
        rollDay()
    }

    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// 日付が変わっていたら「きょう」をリセット
    func rollDay() {
        let today = Self.dayKey(Date())
        guard today != lastDay else { return }
        let yesterday = Self.dayKey(Date().addingTimeInterval(-86400))
        yesterdayMinutes = (lastDay == yesterday) ? todayMinutes : 0
        todayMinutes = 0
        if lastSessionDay != yesterday && lastSessionDay != today { streak = 0 }
        lastDay = today
    }

    // MARK: 成長

    var level: Int { 1 + totalMinutes / 360 }
    var stageName: String {
        switch totalMinutes {
        case ..<(30 * 60): return "子犬"
        case ..<(100 * 60): return "わか犬"
        default: return "相棒"
        }
    }
    var nextStage: (name: String, hoursLeft: Int, progress: Double)? {
        if totalMinutes < 30 * 60 {
            return ("わか犬", Int(ceil(Double(30 * 60 - totalMinutes) / 60)), Double(totalMinutes) / Double(30 * 60))
        }
        if totalMinutes < 100 * 60 {
            return ("相棒", Int(ceil(Double(100 * 60 - totalMinutes) / 60)),
                    Double(totalMinutes - 30 * 60) / Double(70 * 60))
        }
        return nil
    }

    // MARK: セッション

    func elapsed(at date: Date = Date()) -> TimeInterval {
        guard let s = sessionStart else { return 0 }
        let pausing = peekStart.map { max(0, date.timeIntervalSince($0)) } ?? 0
        return max(0, date.timeIntervalSince(s) - pausedTotal - pausing) + demoBoost
    }

    /// はじめる → まず「基地に置こう」
    func start(_ plan: SessionPlan) {
        pendingPlan = plan
        useBase = plan.useBase
        if plan.useBase { flow = .base } else { begin(atBase: false) }
    }

    /// 深呼吸をたす。新しくひらいた ごほうび を返す
    func addBreath(seconds: Double) -> [RoadReward] {
        let m = seconds >= 30 ? max(1, Int(seconds / 60)) : 0
        guard m > 0 else { return [] }
        let before = breathMinutes
        breathMinutes += m
        return Road.all.filter { $0.minutes > before && $0.minutes <= breathMinutes }
    }

    /// 基地に置けた（または基地なし）で、ほんとうにはじめる
    func begin(atBase: Bool) {
        guard let plan = pendingPlan else { return }
        pendingPlan = nil
        self.atBase = atBase
        sessionTitle = plan.title
        sessionGoal = plan.goalMinutes
        sessionStart = Date()
        demoBoost = 0
        maxLives = plan.lives
        peekMinutes = plan.peekMinutes
        lives = plan.lives
        peekUntil = nil
        peekStart = nil
        pausedTotal = 0
        SessionShield.on()
        Haptic.success()
        flow = .running
    }

    func finish() {
        guard sessionStart != nil else { return }
        if peekStart != nil { endPeek() }
        var minutes = Int(elapsed() / 60)
        if sessionGoal > 0 { minutes = min(minutes, sessionGoal) }
        sessionStart = nil
        demoBoost = 0
        peekUntil = nil
        SessionShield.off()
        rollDay()
        let gotBones = minutes / 30
        let mult = rewardMultiplier(lives: maxLives, peekMinutes: peekMinutes)
        let battery = UIDevice.current.batteryState
        let bonus = atBase && (battery == .charging || battery == .full)
        let gotStars = Int((Double(minutes) * mult * (bonus ? 1.2 : 1)).rounded())
        atBase = false
        todayMinutes += minutes
        totalMinutes += minutes
        weekMinutes += minutes
        stars += gotStars
        bones += gotBones
        let today = Self.dayKey(Date())
        if minutes > 0 && lastSessionDay != today {
            streak += 1
            lastSessionDay = today
        }
        Haptic.success()
        flow = .result(SessionResult(minutes: minutes, bones: gotBones, stars: gotStars, multiplier: mult, baseBonus: bonus))
    }

    /// 中断する：ライフを1つ使って、決めた分数だけブロックを止める
    func peek() {
        guard lives > 0, peekUntil == nil else { return }
        lives -= 1
        peekStart = Date()
        peekUntil = Date().addingTimeInterval(Double(peekMinutes * 60))
        SessionShield.off()
        Haptic.medium()
    }

    /// 中断おわり：ブロックをもどして、タイマーを再開
    func endPeek(at date: Date = Date()) {
        if let ps = peekStart {
            let end = min(date, peekUntil ?? date)
            pausedTotal += max(0, end.timeIntervalSince(ps))
        }
        peekStart = nil
        peekUntil = nil
        SessionShield.on()
    }

    /// 毎秒よぶ：5分たったらブロックをもどす／ゴールに着いたら自動でおわる
    func tick(_ now: Date = Date()) {
        guard sessionStart != nil else { return }
        if let p = peekUntil, now >= p {
            endPeek(at: p)
            Haptic.soft(0.7)
        }
        if peekStart == nil && sessionGoal > 0 && elapsed(at: now) >= Double(sessionGoal * 60) {
            finish()
        }
    }

    /// アプリをひらいたとき：夜のロックを登録しなおし、朝なら ゆうべの分を足す
    func checkNight() {
        rollDay()
        NightLock.apply()
        guard let m = NightLock.morningCredit() else { return }
        todayMinutes += m
        totalMinutes += m
        weekMinutes += m
        stars += m / 6
        let today = Self.dayKey(Date())
        if lastSessionDay != today { streak += 1; lastSessionDay = today }
        nightToast = m
    }

    func log(_ key: String) { activity[key, default: 0] += 1 }

    /// やりたいことを5分だけ やってみる
    func tryGoal(_ g: Goal) {
        log("goal:" + g.title)
        trialGoal = g.title
        start(SessionPlan(title: g.title, goalMinutes: 5, lives: maxLives, peekMinutes: peekMinutes, useBase: useBase))
    }

    /// どうだった？ 0 = すき, 1 = ふつう, 2 = ちがうかも
    func rateTrial(_ r: Int) {
        guard let t = trialGoal else { return }
        trialGoal = nil
        guard r == 0, let i = goals.firstIndex(where: { $0.title == t }) else { return }
        log("fav:" + t)
        var g = goals.remove(at: i)
        g.fav = true
        goals.insert(g, at: 0)
    }

    func cancelPick() { flow = nil; pendingPlan = nil; trialGoal = nil }
    func closeResult() { flow = nil; trialGoal = nil }
}

/// セッション中だけ、設定で選んだアプリ（SNS）をブロックする
enum SessionShield {
    #if DEMO
    // デモ版（TestFlight）はスクリーンタイムの許可がないので、ブロックしない
    static func on() {}
    static func off() {}
    #else
    private static let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("session"))

    static func on() {
        guard AuthorizationCenter.shared.authorizationStatus == .approved else { return }
        let s = SharedSettings.selection
        store.shield.applications = s.applicationTokens.isEmpty ? nil : s.applicationTokens
        store.shield.applicationCategories = s.categoryTokens.isEmpty ? nil : .specific(s.categoryTokens)
        store.shield.webDomains = s.webDomainTokens.isEmpty ? nil : s.webDomainTokens
    }

    static func off() {
        store.clearAllSettings()
    }
    #endif
}
