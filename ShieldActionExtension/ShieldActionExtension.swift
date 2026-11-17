import ManagedSettings
import Foundation

/// ブロック画面のボタン。「ちょっとだけ開く」は、ドパ抜きでひと呼吸してから開く（通知からアプリへ）
class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler)
    }
    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler)
    }
    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler)
    }

    private func respond(_ action: ShieldAction, _ done: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .secondaryButtonPressed:
            Shields.notify("preopen", title: "ドパ抜きちゃん", body: "ドパ抜きちゃんのところで、ひと呼吸してから開こ", kind: "preopen")
            done(.close)
        default:
            done(.close)
        }
    }
}
