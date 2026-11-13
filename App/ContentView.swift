import SwiftUI
import FamilyControls
import DeviceActivity

struct ContentView: View {
    @State private var authorized = AuthorizationCenter.shared.authorizationStatus == .approved
    @State private var selection = SharedSettings.selection
    @State private var showPicker = false
    @State private var alwaysBlocked = SharedSettings.alwaysBlocked
    @State private var showAlwaysPicker = false
    @State private var showInstagramDM = false
    @State private var limit = SharedSettings.dailyLimitMinutes
    @State private var nightOn = SharedSettings.nightBlockEnabled
    @State private var nightStart = SharedSettings.nightStartHour
    @State private var nightEnd = SharedSettings.nightEndHour
    @State private var message = ""
    @State private var tip = DetoxTips.random()

    var body: some View {
        NavigationStack {
            Form {
                if authorized {
                    Section {
                        // 表示は ReportExtension が担当（数字はアプリ本体からは読めない）
                        DeviceActivityReport(
                            DeviceActivityReport.Context("totalActivity"),
                            filter: DeviceActivityFilter(
                                segment: .daily(during: Calendar.current.dateInterval(of: .day, for: .now)!)
                            )
                        )
                        .frame(minHeight: 260)
                    }
                }

                Section {
                    Text("💡 " + tip).font(.callout)
                } header: { Text("今日のデトックスTips") }
                if !authorized {
                    Section {
                        Button("スクリーンタイムの利用を許可する") { Task { await requestAuth() } }
                    } footer: { Text("制限をかけるために最初に1回だけ許可が必要です。") }
                }

                Section {
                    Button {
                        showInstagramDM = true
                    } label: {
                        Label("インスタのDMを開く", systemImage: "paperplane")
                    }
                } footer: { Text("リールは表示されません。初回だけインスタへのログインが必要です。") }

                Section {
                    Button("アプリを選ぶ（インスタ・YouTube）") { showAlwaysPicker = true }
                        .familyActivityPicker(isPresented: $showAlwaysPicker, selection: $alwaysBlocked)
                    Text("選択中: アプリ \(alwaysBlocked.applicationTokens.count)件")
                        .foregroundStyle(.secondary)
                } header: { Text("アプリ版は常にブロック") } footer: {
                    Text("リール・ショート以外はSafariのブラウザ版で使います。設定 > アプリ > Safari > 拡張機能 で「SNSリミッター」のブロッカーをオンにしてください。")
                }

                Section("時間制限するアプリ") {
                    Button("アプリを選ぶ（TikTokなど）") { showPicker = true }
                    Text("選択中: アプリ \(selection.applicationTokens.count)件 / カテゴリ \(selection.categoryTokens.count)件")
                        .foregroundStyle(.secondary)
                }

                Section("1日の時間制限") {
                    Stepper("1日 \(limit) 分まで", value: $limit, in: 5...240, step: 5)
                }

                Section("夜間ブロック") {
                    Toggle("夜はブロックする", isOn: $nightOn)
                    if nightOn {
                        Stepper("開始 \(nightStart):00", value: $nightStart, in: 0...23)
                        Stepper("終了 \(nightEnd):00", value: $nightEnd, in: 0...23)
                    }
                }

                Section {
                    Button("この設定で制限を開始") { apply() }
                        .disabled(!authorized || selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && alwaysBlocked.applicationTokens.isEmpty)
                    Button("制限をすべて止める", role: .destructive) {
                        LimitScheduler.stopAll(); message = "制限を止めました"
                    }
                }

                if !message.isEmpty { Text(message).foregroundStyle(.secondary) }
            }
            .navigationTitle("SNSリミッター")
            .familyActivityPicker(isPresented: $showPicker, selection: $selection)
            .sheet(isPresented: $showInstagramDM) {
                SafariView(url: URL(string: "https://www.instagram.com/direct/inbox/")!)
                    .ignoresSafeArea()
            }
        }
    }

    private func requestAuth() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorized = true
        } catch {
            message = "許可できませんでした: \(error.localizedDescription)"
        }
    }

    private func apply() {
        SharedSettings.selection = selection
        SharedSettings.alwaysBlocked = alwaysBlocked
        SharedSettings.dailyLimitMinutes = limit
        SharedSettings.nightBlockEnabled = nightOn
        SharedSettings.nightStartHour = nightStart
        SharedSettings.nightEndHour = nightEnd
        do {
            try LimitScheduler.start()
            message = "制限を開始しました（1日\(limit)分" + (nightOn ? "・\(nightStart)時〜\(nightEnd)時はブロック）" : "）")
        } catch {
            message = "開始できませんでした: \(error.localizedDescription)"
        }
    }
}
