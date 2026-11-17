import ManagedSettings
import ManagedSettingsUI
import UIKit

/// ブロック中のアプリを開いたときに出る画面
class ShieldExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration { make() }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { make() }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { make() }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { make() }

    private func make() -> ShieldConfiguration {
        let goal = SharedSettings.goalEnabled && Shields.goalHitToday && !Shields.isNight() && !Shields.sessionActive
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 0.85),
            icon: UIImage(named: "dog"),
            title: .init(text: goal ? "きょうはここまでにしよ？" : "いま開く？", color: .white),
            subtitle: .init(text: "ドパ抜きちゃんが聞いてるよ\n\n💡 " + DetoxTips.random(), color: UIColor(white: 0.75, alpha: 1)),
            primaryButtonLabel: .init(text: "やめとく", color: .white),
            primaryButtonBackgroundColor: UIColor(red: 0.30, green: 0.55, blue: 0.94, alpha: 1),
            secondaryButtonLabel: .init(text: "ちょっとだけ開く", color: UIColor(white: 0.85, alpha: 1))
        )
    }
}
