import SwiftUI
import FamilyControls
import DeviceActivity
import UserNotifications

/// おやすみロック：既存の夜間ブロック（DeviceActivity の .night と MonitorExtension）をそのまま使う
enum NightLock {
    static var isAuthorized: Bool { AuthorizationCenter.shared.authorizationStatus == .approved }
    static var hasTargets: Bool {
        let s = SharedSettings.selection
        return !(s.applicationTokens.isEmpty && s.categoryTokens.isEmpty && s.webDomainTokens.isEmpty)
    }
    #if DEMO
    static var isReady: Bool { isOn }   // デモ版は見た目だけ（ブロックはしない）
    #else
    static var isReady: Bool { isAuthorized && hasTargets }
    #endif
    static var isOn: Bool { SharedSettings.nightBlockEnabled }
    static var start: Int { SharedSettings.nightStartHour }
    static var end: Int { SharedSettings.nightEndHour }

    static var rangeText: String { String(format: "%d:00〜%d:00", start, end) }
    static var nightMinutes: Int { ((end - start + 24) % 24) * 60 }

    /// はじめての夜（と、ねる時間をかえたとき）だけ、犬が予告する。予告するセリフを返す
    static func takeNotice() -> String? {
        guard isOn, isReady else { return nil }
        let key = "\(start)-\(end)"
        let d = UserDefaults.standard
        guard d.string(forKey: "p.nightNotice") != key else { return nil }
        d.set(key, forKey: "p.nightNotice")
        scheduleReminder()
        return "今夜\(start)時からロックするよ。いっしょにねよ〜"
    }

    /// ロックの30分前に1回だけ おしらせ（許可はこのときだけ聞く）
    private static func scheduleReminder() {
        let cal = Calendar.current
        guard var at = cal.date(bySettingHour: start, minute: 0, second: 0, of: Date())?.addingTimeInterval(-30 * 60) else { return }
        if at <= Date() { at = at.addingTimeInterval(86400) }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { ok, _ in
            guard ok else { return }
            let c = UNMutableNotificationContent()
            c.title = "ドパ抜きちゃん"
            c.body = "あと30分で おやすみロックだよ。そろそろ スマホを基地に置こ〜"
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: at)
            let req = UNNotificationRequest(identifier: "nightNotice",
                                            content: c,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
            center.add(req)
        }
    }

    /// いまが ねる時間か
    static func isSleepTime(_ date: Date = Date()) -> Bool {
        let h = Calendar.current.component(.hour, from: date)
        return start <= end ? (h >= start && h < end) : (h >= start || h < end)
    }

    /// 夜のスケジュールだけを登録しなおす（1日の上限 .daily には さわらない）。同じ設定なら何もしない
    static func apply() {
        #if DEMO
        return
        #endif
        let center = DeviceActivityCenter()
        guard isOn && isReady else {
            center.stopMonitoring([.night])
            Blocker.unblock(.nightBlock)
            return
        }
        if let cur = center.schedule(for: .night),
           cur.intervalStart.hour == start, cur.intervalEnd.hour == end {
            if UserDefaults.standard.object(forKey: "p.nightArmed") == nil {
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "p.nightArmed")
            }
            return
        }
        let night = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: start, minute: 0),
            intervalEnd: DateComponents(hour: end, minute: 0),
            repeats: true
        )
        do {
            try center.startMonitoring(.night, during: night)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "p.nightArmed")
        } catch {
            print("night lock:", error)
        }
    }

    /// きのうの夜からロックが有効だったら、けさ1回だけ「取り戻した時間」に足す分数
    static func morningCredit(now: Date = Date()) -> Int? {
        #if DEMO
        return nil
        #endif
        let d = UserDefaults.standard
        guard isOn, isReady else { return nil }
        let cal = Calendar.current
        let h = cal.component(.hour, from: now)
        guard h >= end, h < 15 else { return nil }      // 起きる時間〜昼すぎまで
        let today = GameState.dayKey(now)
        guard d.string(forKey: "p.nightCredited") != today else { return nil }
        // ゆうべ ねる時間の時点で、もうロックが登録されていたか
        guard let armed = d.object(forKey: "p.nightArmed") as? Double,
              var bed = cal.date(bySettingHour: start, minute: 0, second: 0, of: now) else { return nil }
        if bed > now { bed = bed.addingTimeInterval(-86400) }
        guard Date(timeIntervalSince1970: armed) <= bed else { return nil }
        d.set(today, forKey: "p.nightCredited")
        return nightMinutes
    }
}

/// おやすみロックの設定シート
struct NightLockSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var on = SharedSettings.nightBlockEnabled
    @State private var start = SharedSettings.nightStartHour
    @State private var end = SharedSettings.nightEndHour
    @State private var authorized = NightLock.isAuthorized
    @State private var selection = SharedSettings.selection
    @State private var showPicker = false
    @State private var message: String?

    private var hasTargets: Bool {
        !(selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button { dismiss() } label: { CircleIcon(system: "xmark") }.buttonStyle(PressStyle())
                    Spacer()
                }
                HStack(spacing: 12) {
                    DogView(size: 80, mood: .sleep)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("おやすみロック").font(.dp(26, .heavy))
                        Text("ねてる間も、ちゃんと取り戻した時間になるよ").font(.dp(13, .bold)).foregroundColor(DP.gray)
                    }
                }

                Toggle(isOn: $on) { Text("毎晩じどうでロック").font(.dp(15, .heavy)) }
                    .tint(DP.violet)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))

                if on {
                    HStack(spacing: 10) {
                        hourBox("ねる", $start)
                        Image(systemName: "arrow.right").foregroundColor(DP.gray)
                        hourBox("おきる", $end)
                    }
                    #if DEMO
                    Text("デモ版なので、ほんとうのロックはかかりません。本番では、この時間にSNSがロックされるよ")
                        .font(.dp(13, .bold)).foregroundColor(DP.gray)
                        .fixedSize(horizontal: false, vertical: true)
                    #else
                    step(1, done: authorized, title: "スクリーンタイムを許可", button: "許可する") { await authorize() }
                    step(2, done: hasTargets, title: hasTargets ? "ブロックするアプリ：えらんだ" : "ブロックするアプリをえらぶ",
                         button: hasTargets ? "えらびなおす" : "えらぶ") { showPicker = true }
                        .disabled(!authorized)
                        .opacity(authorized ? 1 : 0.5)
                    #endif
                }

                if let m = message {
                    Text(m).font(.dp(13, .bold)).foregroundColor(DP.yellow)
                }

                Button(action: save) { Label("これできめる", systemImage: "moon.fill") }
                    .buttonStyle(PuffyStyle(color: .purple, height: 58))
                    .padding(.top, 4)
            }
            .padding(20)
        }
        .background(TopGlow(color: DP.purple.opacity(0.6), reach: 0.45))
        .background(DP.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onChange(of: selection) { s in SharedSettings.selection = s }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: on)
    }

    private func hourBox(_ label: String, _ hour: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.dp(12, .heavy)).foregroundColor(DP.gray)
            Picker(label, selection: hour) {
                ForEach(0..<24, id: \.self) { h in Text(String(format: "%d:00", h)).tag(h) }
            }
            .pickerStyle(.menu)
            .tint(.white)
            .font(.num(20))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
    }

    private func step(_ n: Int, done: Bool, title: String, button: String, action: @escaping () async -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "\(n).circle")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(done ? DP.green : DP.gray)
            Text(title).font(.dp(14, .heavy))
            Spacer()
            if !done || n == 2 {
                Button(button) { Task { await action() } }
                    .buttonStyle(PuffyStyle(color: .white, height: 36, fullWidth: false, strong: false))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
    }

    private func authorize() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorized = NightLock.isAuthorized
        } catch {
            message = "許可できなかったよ（実機で試してね）"
        }
    }

    private func save() {
        SharedSettings.nightBlockEnabled = on
        SharedSettings.nightStartHour = start
        SharedSettings.nightEndHour = end
        NightLock.apply()
        Haptic.success()
        if on && !(authorized && hasTargets) {
            message = "許可とアプリえらびがおわると、ロックがはじまるよ"
        } else {
            dismiss()
        }
    }
}
