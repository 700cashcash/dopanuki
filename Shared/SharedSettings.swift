import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

/// アプリ本体と拡張機能で共有する設定（App Group の UserDefaults に保存）
enum SharedSettings {
    static let appGroup = "group.com.isk.dopanuki"   // project.yml と合わせる
    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup)! }

    // 制限対象（ユーザーが FamilyActivityPicker で選んだインスタ・TikTok・YouTube）
    static var selection: FamilyActivitySelection {
        get {
            guard let data = defaults.data(forKey: "selection"),
                  let value = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            else { return FamilyActivitySelection() }
            return value
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "selection") }
    }

    // 常にブロックするアプリ（インスタ・YouTubeのアプリ版。ブラウザ版で使う前提）
    static var alwaysBlocked: FamilyActivitySelection {
        get {
            guard let data = defaults.data(forKey: "alwaysBlocked"),
                  let value = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            else { return FamilyActivitySelection() }
            return value
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "alwaysBlocked") }
    }

    static var dailyLimitMinutes: Int {
        get { defaults.object(forKey: "dailyLimitMinutes") as? Int ?? 30 }
        set { defaults.set(newValue, forKey: "dailyLimitMinutes") }
    }
    static var nightBlockEnabled: Bool {
        get { defaults.object(forKey: "nightBlockEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "nightBlockEnabled") }
    }
    static var nightStartHour: Int {
        get { defaults.object(forKey: "nightStartHour") as? Int ?? 23 }
        set { defaults.set(newValue, forKey: "nightStartHour") }
    }
    static var nightEndHour: Int {
        get { defaults.object(forKey: "nightEndHour") as? Int ?? 7 }
        set { defaults.set(newValue, forKey: "nightEndHour") }
    }
}

extension DeviceActivityName {
    static let daily = Self("daily")   // 1日の利用時間をカウント
    static let night = Self("night")   // 夜間ブロックの時間帯
}

extension DeviceActivityEvent.Name {
    static let limitReached = Self("limitReached")
}

extension ManagedSettingsStore.Name {
    static let dailyLimit = Self("dailyLimit")   // 時間切れによるブロック
    static let nightBlock = Self("nightBlock")   // 夜間ブロック
    static let always = Self("always")           // アプリ版の常時ブロック
}

/// 指定したストアで対象アプリをブロック／解除する
enum Blocker {
    static func block(_ name: ManagedSettingsStore.Name) {
        let store = ManagedSettingsStore(named: name)
        let s = name == .always ? SharedSettings.alwaysBlocked : SharedSettings.selection
        store.shield.applications = s.applicationTokens.isEmpty ? nil : s.applicationTokens
        store.shield.applicationCategories = s.categoryTokens.isEmpty ? nil : .specific(s.categoryTokens)
        store.shield.webDomains = s.webDomainTokens.isEmpty ? nil : s.webDomainTokens
    }
    static func unblock(_ name: ManagedSettingsStore.Name) {
        ManagedSettingsStore(named: name).clearAllSettings()
    }
}
