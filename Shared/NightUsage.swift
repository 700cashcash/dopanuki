import Foundation
import DeviceActivity

/// 寝る時間のあとに「時間を食べるアプリ」を使った分数（夜ふかし）。
/// 監視拡張がしきい値イベントで記録し、アプリが朝に読む（App Group に保存）
enum NightUsage {
    static let thresholds = [5, 30, 60, 120]

    static func eventName(_ minutes: Int) -> DeviceActivityEvent.Name { .init("nightUse\(minutes)") }

    /// その時刻が属する夜（寝る時間の日付）。0時すぎは前の日の夜
    static func nightKey(_ date: Date) -> String {
        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let start = SharedSettings.nightStartHour, end = SharedSettings.nightEndHour
        let base = (start > end && h < end) ? date.addingTimeInterval(-86400) : date
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: base)
    }

    /// 拡張から：しきい値に届いた
    static func record(event: DeviceActivityEvent.Name, at date: Date = Date()) {
        let raw = event.rawValue
        guard raw.hasPrefix("nightUse"), let m = Int(raw.dropFirst("nightUse".count)) else { return }
        let key = "nightUsage." + nightKey(date)
        let d = SharedSettings.defaults
        d.set(max(d.integer(forKey: key), m), forKey: key)
    }

    /// ゆうべ使った分（しきい値の段階）
    static func minutes(lastNightOf date: Date) -> Int {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let key = "nightUsage." + f.string(from: date.addingTimeInterval(-86400))
        return SharedSettings.defaults.integer(forKey: key)
    }

    /// 0 = ツヤツヤ, 1 = うっすらクマ, 2 = こいクマ, 3 = 灰色・読み込み中, 4 = 四角くなりかけ
    static func level(forMorning date: Date) -> Int {
        let m = minutes(lastNightOf: date)
        return thresholds.filter { m >= $0 }.count
    }
}
