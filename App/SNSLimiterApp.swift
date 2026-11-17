import SwiftUI
import UserNotifications

@main
struct SNSLimiterApp: App {
    init() {
        // 通知をタップしたら、ブロック画面の「ちょっとだけ開く」や毎日の時間へ
        UNUserNotificationCenter.current().delegate = Router.shared
    }

    var body: some Scene {
        // ローンチ版（ツール＋キャラ）。ゲーム版のプロトタイプは ProtoRoot（タグ proto-v1）
        WindowGroup {
            if AppMode.launch { LaunchRoot() } else { ProtoRoot() }
        }
    }
}
