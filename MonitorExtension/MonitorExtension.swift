import DeviceActivity
import ManagedSettings

/// OS がバックグラウンドで呼び出す監視拡張。ここでブロックのON/OFFを切り替える
class MonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        switch activity {
        case .daily: Blocker.unblock(.dailyLimit)  // 新しい1日：時間制限をリセット
        case .night: Blocker.block(.nightBlock)    // 夜間ブロック開始
        default: break
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if activity == .night { Blocker.unblock(.nightBlock) }  // 朝になったら解除
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        if event == .limitReached { Blocker.block(.dailyLimit) }  // 今日の上限に到達
        if activity == .night { NightUsage.record(event: event) } // 夜ふかしした分を記録
    }
}
