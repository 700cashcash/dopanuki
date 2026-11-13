import ManagedSettings
import ManagedSettingsUI
import UIKit

/// ブロック中のアプリを開いたときに出る画面の文言
class ShieldExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(name: application.localizedDisplayName)
    }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: application.localizedDisplayName)
    }

    private func make(name: String?) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            icon: UIImage(systemName: "hourglass"),
            title: .init(text: "\(name ?? "このアプリ")は今は使えません", color: .label),
            subtitle: .init(text: "今日の時間を使い切ったか、ブロック中の時間帯です。\n\n💡 " + DetoxTips.random(), color: .secondaryLabel),
            primaryButtonLabel: .init(text: "閉じる", color: .white),
            primaryButtonBackgroundColor: .systemIndigo
        )
    }
}
