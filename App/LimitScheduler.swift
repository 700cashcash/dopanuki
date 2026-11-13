import DeviceActivity
import Foundation

/// DeviceActivityCenter に監視スケジュールを登録する
enum LimitScheduler {
    static func start() throws {
        let center = DeviceActivityCenter()
        center.stopMonitoring()
        Blocker.unblock(.dailyLimit)
        Blocker.unblock(.nightBlock)
        Blocker.block(.always)   // アプリ版インスタ・YouTubeは即ブロック（未選択なら何もしない）

        let s = SharedSettings.selection
        let hasTargets = !(s.applicationTokens.isEmpty && s.categoryTokens.isEmpty && s.webDomainTokens.isEmpty)
        guard hasTargets else { return }   // 時間制限の対象がなければ常時ブロックだけで終わり

        // 毎日 0:00〜23:59 の間、選んだアプリの合計利用時間を数え、上限に達したらイベント発火
        let daily = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        let event = DeviceActivityEvent(
            applications: s.applicationTokens,
            categories: s.categoryTokens,
            webDomains: s.webDomainTokens,
            threshold: DateComponents(minute: SharedSettings.dailyLimitMinutes)
        )
        try center.startMonitoring(.daily, during: daily, events: [.limitReached: event])

        // 夜間ブロック（日付をまたぐ時間帯もOK）
        if SharedSettings.nightBlockEnabled {
            let night = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: SharedSettings.nightStartHour, minute: 0),
                intervalEnd: DateComponents(hour: SharedSettings.nightEndHour, minute: 0),
                repeats: true
            )
            try center.startMonitoring(.night, during: night)
        }
    }

    static func stopAll() {
        DeviceActivityCenter().stopMonitoring()
        Blocker.unblock(.dailyLimit)
        Blocker.unblock(.nightBlock)
        Blocker.unblock(.always)
    }
}
