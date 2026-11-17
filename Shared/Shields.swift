import Foundation
import DeviceActivity
import ManagedSettings
import UserNotifications

extension ManagedSettingsStore.Name {
    static let session = Self("session")         // アプリでのセッション中
    static let routine = Self("routine")         // 毎日いっしょに置く時間
}

extension DeviceActivityName {
    static let relock = Self("relock")           // 「ちょっとだけ開く」のあと、ブロックを戻す
    static func routine(_ weekday: Int) -> Self { Self("routine.\(weekday)") }   // 0 = 毎日
}

extension DeviceActivityEvent.Name {
    static let goalReached = Self("goalReached")
    static let goalHalf = Self("goalHalf")
    static let goalLeft10 = Self("goalLeft10")
    static func goalUsage(_ m: Int) -> Self { Self("goalUse\(m)") }
}

/// 1日の目標・毎日いっしょに置く時間（アプリと拡張で共有）
extension SharedSettings {
    static var goalEnabled: Bool {
        get { defaults.object(forKey: "goalEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "goalEnabled") }
    }
    /// 時間を食べるアプリを 1日どれくらいまで（分）
    static var goalMinutes: Int {
        get { defaults.object(forKey: "goalMinutes") as? Int ?? 60 }
        set { defaults.set(newValue, forKey: "goalMinutes") }
    }
    static var routineEnabled: Bool {
        get { defaults.object(forKey: "routineEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "routineEnabled") }
    }
    static var routineStartHour: Int {
        get { defaults.object(forKey: "routineStart") as? Int ?? 20 }
        set { defaults.set(newValue, forKey: "routineStart") }
    }
    static var routineEndHour: Int {
        get { defaults.object(forKey: "routineEnd") as? Int ?? 21 }
        set { defaults.set(newValue, forKey: "routineEnd") }
    }
    /// 曜日（1 = 日曜 … 7 = 土曜）。ぜんぶなら毎日
    static var routineWeekdays: [Int] {
        get { defaults.array(forKey: "routineDays") as? [Int] ?? [1, 2, 3, 4, 5, 6, 7] }
        set { defaults.set(newValue, forKey: "routineDays") }
    }
}

/// いま何をブロックすべきかを見て、ブロックを戻す（アプリ・監視拡張のどちらからも呼ぶ）
enum Shields {
    private static var d: UserDefaults { SharedSettings.defaults }

    static func dayKey(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: 状態（App Group）

    /// アプリのセッション中か（中断中は false）
    static var sessionActive: Bool {
        get { d.bool(forKey: "sessionActive") }
        set { d.set(newValue, forKey: "sessionActive") }
    }
    /// 「ちょっとだけ開く」で外している終わりの時刻
    static var unlockedUntil: Date? {
        get { (d.object(forKey: "unlockedUntil") as? Double).map { Date(timeIntervalSince1970: $0) } }
        set { d.set(newValue?.timeIntervalSince1970, forKey: "unlockedUntil") }
    }
    /// きょう目標に届いた
    static var goalHitToday: Bool { d.string(forKey: "goalHitDay") == dayKey() }
    static func markGoalHit() { d.set(dayKey(), forKey: "goalHitDay") }

    /// きょう使った分（5分きざみ・目標までのしきい値で記録）
    static var usageToday: Int { d.integer(forKey: "goalUsage." + dayKey()) }
    static func recordUsage(_ m: Int) {
        let k = "goalUsage." + dayKey()
        d.set(max(d.integer(forKey: k), m), forKey: k)
    }

    // MARK: 時間帯

    static func minutesOfDay(_ date: Date) -> Int {
        let c = Calendar.current
        return c.component(.hour, from: date) * 60 + c.component(.minute, from: date)
    }

    static func inWindow(_ now: Date, start: Int, end: Int) -> Bool {
        let m = minutesOfDay(now), s = start * 60, e = end * 60
        return s <= e ? (m >= s && m < e) : (m >= s || m < e)
    }

    static func isNight(_ now: Date = Date()) -> Bool {
        SharedSettings.nightBlockEnabled && inWindow(now, start: SharedSettings.nightStartHour, end: SharedSettings.nightEndHour)
    }

    /// 毎日いっしょに置く時間か（夜とかさなったら夜を優先）
    static func isRoutine(_ now: Date = Date()) -> Bool {
        guard SharedSettings.routineEnabled, !isNight(now) else { return false }
        let wd = Calendar.current.component(.weekday, from: now)
        guard SharedSettings.routineWeekdays.contains(wd) else { return false }
        return inWindow(now, start: SharedSettings.routineStartHour, end: SharedSettings.routineEndHour)
    }

    // MARK: ブロック

    static let all: [ManagedSettingsStore.Name] = [.session, .nightBlock, .dailyLimit, .routine]

    /// ぜんぶ外す（ちょっとだけ開く・DM）
    static func liftAll() {
        for n in all {
            let s = ManagedSettingsStore(named: n)
            s.shield.applications = nil
            s.shield.applicationCategories = nil
            s.shield.webDomains = nil
            s.shield.webDomainCategories = nil
            s.webContent.blockedByFilter = nil
        }
    }

    /// いまの状態に合わせて、ブロックを戻す
    static func restore(now: Date = Date()) {
        if let u = unlockedUntil, u > now { return }
        unlockedUntil = nil
        sessionActive ? Blocker.block(.session) : Blocker.unblock(.session)
        isNight(now) ? Blocker.block(.nightBlock) : Blocker.unblock(.nightBlock)
        (SharedSettings.goalEnabled && goalHitToday) ? Blocker.block(.dailyLimit) : Blocker.unblock(.dailyLimit)
        isRoutine(now) ? Blocker.block(.routine) : Blocker.unblock(.routine)
    }

    // MARK: ちょっとだけ開く

    /// 決めた分だけ外して、あとで確実に戻す（アプリが閉じていても、監視拡張が戻す）
    static func unlock(minutes: Int) {
        let until = Date().addingTimeInterval(Double(minutes * 60))
        unlockedUntil = until
        liftAll()
        // DeviceActivity は15分以上の区間が必要なので、「戻す時刻」から15分の区間を作って、その始まりで戻す
        let cal = Calendar.current
        let startC = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: until)
        let endC = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: until.addingTimeInterval(16 * 60))
        let center = DeviceActivityCenter()
        center.stopMonitoring([.relock])
        try? center.startMonitoring(.relock, during: DeviceActivitySchedule(intervalStart: startC, intervalEnd: endC, repeats: false))
    }

    // MARK: 通知

    static func notify(_ id: String, title: String, body: String, kind: String, after seconds: Double = 1) {
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.sound = .default
        c.userInfo = ["kind": kind]
        let req = UNNotificationRequest(identifier: id, content: c,
                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false))
        UNUserNotificationCenter.current().add(req)
    }
}
