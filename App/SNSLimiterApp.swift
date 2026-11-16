import SwiftUI

@main
struct SNSLimiterApp: App {
    var body: some Scene {
        // ローンチ版（ツール＋キャラ）。ゲーム版のプロトタイプは ProtoRoot（タグ proto-v1）
        WindowGroup {
            if AppMode.launch { LaunchRoot() } else { ProtoRoot() }
        }
    }
}
