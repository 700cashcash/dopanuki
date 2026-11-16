import SwiftUI

/// 置いた記録（1回のセッション）
struct SessionRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var minutes: Int
    var purpose: String
    var completed: Bool
}

/// 記録タブにたまるカード
struct SavedCard: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case declare, result, kimo, back, week }
    var id = UUID()
    var date = Date()
    var kind: Kind
    var minutes = 0
    var purpose = ""
    var text = ""        // 期間（宣言）・キモさ（キモ朝）・週のまとめ など
}

/// ローンチ版の記録（端末の中だけに保存）
struct LifeData: Codable {
    var onboarded = false
    var records: [SessionRecord] = []
    var cards: [SavedCard] = []
    var customPurposes: [String] = []
    var todayGoal = ""
    var goalDay = ""
    var tomorrowPlan = ""
    var planDay = ""                 // tomorrowPlan を言った夜の日付
    var doneNotes: [String: String] = [:]   // 日付 → きょうできたこと
    var neeneeDay = ""
    var neeneeCount = 0
    var morningAskedDay = ""
    var quizDay = ""
    var pendingQuiz = false
    var quizIndex = 0
    var morningShownDay = ""         // 朝のあいさつ（キモ朝・もどった）を出した日
    var lastKimo = 0                 // きのうの朝のキモさ
    var sleptNights = 0              // 基地でねた夜の数
    var lastSleptKey = ""
    var weekCardKey = ""
    var kimoPreview = -1             // 開発用：-1 = 本物、0〜4 = 見た目を固定
    var sleepTalkDay = ""
    var sleepKey = ""
    var tipOrder: [Int] = []         // tips を出す順番（一周したらシャッフルしなおす）
    var tipPos = 0                // おやすみロックOFFで「おやすみ」した夜（部屋を消灯するだけ）
}

final class LifeState: ObservableObject {
    @Published var data: LifeData { didSet { save() } }
    /// 部屋の「ねえねえ」
    @Published var neenee: Neenee?

    private static let key = "life.v1"

    init() {
        if let d = UserDefaults.standard.data(forKey: Self.key),
           let v = try? JSONDecoder().decode(LifeData.self, from: d) {
            data = v
        } else {
            data = LifeData()
        }
        #if DEBUG
        let d = UserDefaults.standard
        if d.bool(forKey: "debugOnboarded") { data.onboarded = true }
        if d.object(forKey: "debugKimo") != nil { data.kimoPreview = d.integer(forKey: "debugKimo") }
        if d.bool(forKey: "debugSample") { addSamples() }
        #endif
    }

    private func save() {
        if let d = try? JSONEncoder().encode(data) { UserDefaults.standard.set(d, forKey: Self.key) }
    }

    static func today(_ date: Date = Date()) -> String { GameState.dayKey(date) }

    // MARK: 何する？

    static let defaultPurposes = ["勉強", "読書", "筋トレ", "仕事・バイト", "作る", "散歩", "人と話す", "寝る・休む"]
    var purposes: [String] { Self.defaultPurposes + data.customPurposes.filter { !Self.defaultPurposes.contains($0) } }

    func remember(purpose: String) {
        let p = purpose.trimmingCharacters(in: .whitespaces)
        guard !p.isEmpty, !Self.defaultPurposes.contains(p) else { return }
        data.customPurposes.removeAll { $0 == p }
        data.customPurposes.insert(p, at: 0)
        if data.customPurposes.count > 8 { data.customPurposes.removeLast() }
    }

    var todayGoal: String { data.goalDay == Self.today() ? data.todayGoal : "" }

    // MARK: 記録

    func record(_ r: SessionResult) {
        guard !data.records.contains(where: { $0.id == r.id }) else { return }
        data.records.append(SessionRecord(id: r.id, date: Date(), minutes: r.minutes, purpose: r.purpose, completed: r.completed))
        if r.minutes > 0 {
            data.cards.append(SavedCard(kind: .result, minutes: r.minutes, purpose: r.purpose))
        }
        data.pendingQuiz = true
    }

    func addCard(_ c: SavedCard) { data.cards.append(c) }

    var todayMinutes: Int {
        let cal = Calendar.current
        return data.records.filter { cal.isDateInToday($0.date) }.reduce(0) { $0 + $1.minutes }
    }
    var totalMinutes: Int { data.records.reduce(0) { $0 + $1.minutes } }

    /// 直近7日：日ごと・何する？ごとの分数
    func week() -> [(day: Date, purpose: String, minutes: Int)] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date()).addingTimeInterval(-6 * 86400)
        var out: [(Date, String, Int)] = []
        for i in 0..<7 {
            let day = start.addingTimeInterval(Double(i) * 86400)
            let recs = data.records.filter { cal.isDate($0.date, inSameDayAs: day) }
            let grouped = Dictionary(grouping: recs, by: { $0.purpose.isEmpty ? "そのほか" : $0.purpose })
            if grouped.isEmpty { out.append((day, "", 0)) }
            for (p, rs) in grouped { out.append((day, p, rs.reduce(0) { $0 + $1.minutes })) }
        }
        return out
    }

    // MARK: キモさ（夜ふかしした分で、朝の見た目がかわる）

    /// いまの見た目（0 = ツヤツヤ 〜 4 = 四角くなりかけ）
    var kimo: Int {
        if data.kimoPreview >= 0 { return data.kimoPreview }
        return NightUsage.level(forMorning: Date())
    }

    /// 朝はじめて開いたとき：キモ朝・もどった のカードとセリフ
    func morningGreeting() -> (text: String, back: Bool)? {
        let h = Calendar.current.component(.hour, from: Date())
        guard (5..<12).contains(h), data.morningShownDay != Self.today() else { return nil }
        data.morningShownDay = Self.today()
        let k = kimo
        defer { data.lastKimo = k }
        if k == 0 && data.lastKimo > 0 {
            data.cards.append(SavedCard(kind: .back, text: "ツヤツヤ"))
            return ("もどった！ ちゃんとねてくれて、ありがと", true)
        }
        if k > 0 {
            data.cards.append(SavedCard(kind: .kimo, text: "\(k)"))
            return ([
                "おはよ…ちょっとねむいかも",
                "おはよ…目、しょぼしょぼ…",
                "おは…よ……よみこみ中…",
                "おΔよ…▯▯…きのう、おそかった？",
            ][min(k, 4) - 1], false)
        }
        return ("おはよ！ きょうもツヤツヤ", false)
    }

    // MARK: ひとことtips（開くたび。ねえねえの回数には数えない）

    /// 次のtip。前回と同じものは続けて出さない
    func nextTip() -> String {
        let n = DetoxTips.all.count
        if data.tipOrder.count != n || data.tipPos >= n {
            let last = data.tipOrder.last
            var order = Array(0..<n).shuffled()
            if order.first == last, n > 1 { order.swapAt(0, 1) }
            data.tipOrder = order
            data.tipPos = 0
        }
        let t = DetoxTips.all[data.tipOrder[data.tipPos]]
        data.tipPos += 1
        return t
    }

    // MARK: ねえねえ（1日3回まで）

    private var canAsk: Bool {
        if data.neeneeDay != Self.today() { data.neeneeDay = Self.today(); data.neeneeCount = 0 }
        return data.neeneeCount < 3
    }

    /// 部屋をひらいたときに出す「ねえねえ」をえらぶ
    func pickNeenee() {
        guard neenee == nil, data.onboarded, canAsk else { return }
        let h = Calendar.current.component(.hour, from: Date())
        if (5..<14).contains(h) && data.morningAskedDay != Self.today() && todayGoal.isEmpty {
            data.morningAskedDay = Self.today()
            let yesterday = Self.today(Date().addingTimeInterval(-86400))
            if !data.tomorrowPlan.isEmpty && (data.planDay == yesterday || data.planDay == Self.today()) {
                show(.yesterdayPlan(data.tomorrowPlan))
            } else {
                show(.morning)
            }
            return
        }
        if data.pendingQuiz && data.quizDay != Self.today() {
            data.pendingQuiz = false
            data.quizDay = Self.today()
            data.quizIndex = (data.quizIndex + 1) % Quiz.all.count
            show(.quiz(Quiz.all[data.quizIndex]))
            return
        }
        if Int.random(in: 0..<10) == 0 {
            show(.aside(["あ、見ないで…", "いま、おなかの宇宙を整理中…", "ぷぁ…（ねぐせ直してた）", "…んま"].randomElement()!))
        }
    }

    private func show(_ n: Neenee) {
        data.neeneeCount += 1
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { neenee = n }
    }

    func closeNeenee() { withAnimation(.easeOut(duration: 0.2)) { neenee = nil } }

    func setTodayGoal(_ g: String) {
        data.todayGoal = g
        data.goalDay = Self.today()
    }

    /// 寝る前：きょうできたこと・あした何したい
    func saveNight(done: String, tomorrow: String) {
        if !done.isEmpty { data.doneNotes[Self.today()] = done }
        data.tomorrowPlan = tomorrow
        data.planDay = Self.today()
    }

    /// 基地でねた夜をかぞえる
    func countSleep(nightKey: String) {
        guard data.lastSleptKey != nightKey else { return }
        data.lastSleptKey = nightKey
        data.sleptNights += 1
    }

    /// 日曜の夜：週まとめカード
    func weekCardIfNeeded() {
        let cal = Calendar.current
        let now = Date()
        guard cal.component(.weekday, from: now) == 1, cal.component(.hour, from: now) >= 18 else { return }
        let key = Self.today()
        guard data.weekCardKey != key else { return }
        data.weekCardKey = key
        let mins = week().reduce(0) { $0 + $1.minutes }
        guard mins > 0 else { return }
        data.cards.append(SavedCard(kind: .week, minutes: mins, text: Self.movies(mins)))
    }

    static func movies(_ m: Int) -> String {
        if m >= 120 { return "映画\(m / 120)本ぶん" }
        if m >= 24 { return "アニメ\(m / 24)話ぶん" }
        return "\(m)分ぶん"
    }

    #if DEBUG
    private func addSamples() {
        guard data.records.isEmpty else { return }
        let cal = Calendar.current
        let ps = ["勉強", "読書", "筋トレ", "散歩", "勉強", "作る", "人と話す"]
        for i in 0..<7 {
            let day = cal.date(byAdding: .day, value: -i, to: Date())!
            for j in 0..<(1 + i % 3) {
                let m = [25, 40, 15, 60, 30][(i + j) % 5]
                data.records.append(SessionRecord(date: day, minutes: m, purpose: ps[(i + j) % ps.count], completed: true))
            }
        }
        data.cards = [
            SavedCard(kind: .declare, purpose: "英単語", text: "21:30まで"),
            SavedCard(kind: .result, minutes: 40, purpose: "英単語"),
            SavedCard(kind: .kimo, text: "3"),
            SavedCard(kind: .back, text: "ツヤツヤ"),
            SavedCard(kind: .week, minutes: 480, text: "映画4本ぶん"),
            SavedCard(kind: .result, minutes: 25, purpose: "読書"),
        ]
        data.sleptNights = 5
        data.todayGoal = "英単語"
        data.goalDay = Self.today()
    }
    #endif
}

/// 部屋の吹き出しで聞くこと
enum Neenee: Equatable {
    case morning
    case yesterdayPlan(String)
    case quiz(Quiz)
    case aside(String)
}

/// 「これ知ってる？」3択（Shared/DetoxTips から）
struct Quiz: Equatable {
    let icon: String
    let question: String
    let choices: [String]
    let answer: Int
    let why: String

    static let all: [Quiz] = [
        Quiz(icon: "circle.lefthalf.filled", question: "SNSの刺激を弱めるには、画面をどうする？", choices: ["明るくする", "白黒にする", "大きくする"], answer: 1,
             why: "白黒にすると、SNSの刺激が一気に弱まるよ"),
        Quiz(icon: "bell.slash.fill", question: "SNSの通知、どうするのがいい？", choices: ["ぜんぶオン", "ぜんぶオフ", "音だけオン"], answer: 1,
             why: "見に行くのは、自分が決めたときだけ"),
        Quiz(icon: "bed.double.fill", question: "スマホの充電はどこでする？", choices: ["まくらもと", "ベッドから離れた所", "ふとんの中"], answer: 1,
             why: "目覚ましは時計にすると、ぐっすりねむれるよ"),
        Quiz(icon: "sunrise.fill", question: "朝おきて最初の30分は？", choices: ["SNSを見る", "SNSを開かない", "動画を見る"], answer: 1,
             why: "1日のペースを、自分で決められるよ"),
        Quiz(icon: "toilet.fill", question: "トイレにスマホを持ちこまないと？", choices: ["1日10分以上もどる", "何もかわらない", "時間がへる"], answer: 0,
             why: "それだけで1日10分以上取り戻せることも"),
        Quiz(icon: "wind", question: "「なんとなく開いた」と気づいたら？", choices: ["そのまま見る", "深呼吸を3回して閉じる", "別のSNSへ"], answer: 1,
             why: "3回の深呼吸で、手がとまるよ"),
        Quiz(icon: "timer", question: "スクロールを始める前に決めるといいのは？", choices: ["何分見るか", "何を食べるか", "何も決めない"], answer: 0,
             why: "先に決めておくと、ちゃんと止まれる"),
        Quiz(icon: "person.2.fill", question: "おすすめ欄とフォロー中、早く満足できるのは？", choices: ["おすすめ欄", "フォロー中", "どっちも同じ"], answer: 1,
             why: "フォローしている人の投稿だけのほうが、早く満足できるよ"),
        Quiz(icon: "figure.walk", question: "15分の散歩で、どうなる？", choices: ["つかれるだけ", "気分が上向き", "ねむくなる"], answer: 1,
             why: "歩くと、気分が上向きになるよ"),
        Quiz(icon: "book.fill", question: "本を10ページだけ読むと？", choices: ["続きが気になる", "つまらない", "目がつかれる"], answer: 0,
             why: "続きが気になったら、勝ち"),
        Quiz(icon: "house.fill", question: "ホーム画面のSNSアプリ、どこに置く？", choices: ["1ページ目", "フォルダの奥", "ドック"], answer: 1,
             why: "目に入らないだけで、開く回数がへるよ"),
        Quiz(icon: "fork.knife", question: "ご飯のとき、スマホは？", choices: ["となりに置く", "別の場所に置く", "見ながら食べる"], answer: 1,
             why: "味に集中すると、もっとおいしい"),
    ]
}
