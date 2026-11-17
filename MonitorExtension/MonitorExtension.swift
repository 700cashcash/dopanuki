import DeviceActivity
import ManagedSettings
import Foundation

/// OS がバックグラウンドで呼び出す監視拡張。ここでブロックのON/OFFを切り替える
class MonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        switch activity {
        case .daily:                               // 新しい1日：目標のブロックをリセット
            Blocker.unblock(.dailyLimit)
        case .night:                               // 夜間ブロック開始（おやすみロックがOFFなら計測だけ）
            if SharedSettings.nightBlockEnabled && !unlocked { Blocker.block(.nightBlock) }
        case .relock:                              // 「ちょっとだけ開く」の時間がおわった
            Shields.unlockedUntil = nil
            Shields.restore()
        default:
            if activity.rawValue.hasPrefix("routine."), Shields.isRoutine() {
                // 毎日いっしょに置く時間（夜とかさなったら夜を優先）
                if !unlocked { Blocker.block(.routine) }
                SharedSettings.defaults.set(Date().timeIntervalSince1970, forKey: "routineStartedAt")
                Shields.notify("routine", title: "ドパ抜きちゃん", body: "スマホおこう、いっしょに取り戻そ", kind: "routine")
            }
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if activity == .night { Blocker.unblock(.nightBlock) }  // 朝になったら解除
        if activity.rawValue.hasPrefix("routine.") {
            Blocker.unblock(.routine)
            let d = SharedSettings.defaults
            if let s = d.object(forKey: "routineStartedAt") as? Double {
                // 次にアプリを開いたとき、おかえりリアクションを出す
                d.set("\(s)|\(Date().timeIntervalSince1970)", forKey: "routineDone")
                d.removeObject(forKey: "routineStartedAt")
            }
        }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        if activity == .night { NightUsage.record(event: event); return }   // 夜ふかしした分を記録
        guard activity == .daily else { return }
        let raw = event.rawValue
        if raw.hasPrefix("goalUse"), let m = Int(raw.dropFirst("goalUse".count)) {
            Shields.recordUsage(m)
        }
        switch event {
        case .goalReached:
            Shields.markGoalHit()
            Shields.recordUsage(SharedSettings.goalMinutes)
            if !unlocked { Blocker.block(.dailyLimit) }
        case .goalHalf:
            Shields.notify("goalHalf", title: "ドパ抜きちゃん", body: "きょうの目標の半分まで来たよ", kind: "info")
        case .goalLeft10:
            Shields.notify("goalLeft10", title: "ドパ抜きちゃん", body: "目標まで、あと10分だよ", kind: "info")
        default:
            break
        }
    }

    /// 「ちょっとだけ開く」中は、ブロックをかけ直さない
    private var unlocked: Bool { (Shields.unlockedUntil ?? .distantPast) > Date() }
}
