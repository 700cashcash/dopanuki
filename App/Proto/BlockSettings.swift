import SwiftUI
import FamilyControls
import ManagedSettings

/// 設定：ブロックするアプリをえらぶ（セッション中・おやすみロックで使う）
struct BlockSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var authorized = NightLock.isAuthorized
    @State private var selection = SharedSettings.selection
    @State private var showPicker = false
    @State private var showDM = false
    @State private var message: String?

    private var appCount: Int { selection.applicationTokens.count }
    private var catCount: Int { selection.categoryTokens.count }
    private var webCount: Int { selection.webDomainTokens.count }
    private var hasTargets: Bool { appCount + catCount + webCount > 0 }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button { dismiss() } label: { CircleIcon(system: "xmark") }.buttonStyle(PressStyle())
                    Spacer()
                }
                HStack(spacing: 12) {
                    DogView(size: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("設定").font(.dp(28, .heavy))
                        Text("セッション中と おやすみロックで ブロックするアプリ").font(.dp(13, .bold)).foregroundColor(DP.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                step(1, done: authorized, title: authorized ? "スクリーンタイム：許可ずみ" : "スクリーンタイムを許可",
                     sub: "ブロックするために、最初に1回だけ必要") {
                    if !authorized {
                        Button("許可する") { Task { await authorize() } }
                            .buttonStyle(PuffyStyle(color: .blue, height: 38, fullWidth: false))
                    }
                }

                step(2, done: hasTargets, title: "ブロックするアプリ",
                     sub: hasTargets ? "アプリ \(appCount)・カテゴリ \(catCount)・サイト \(webCount)" : "まだ えらんでないよ") {
                    Button(hasTargets ? "えらびなおす" : "えらぶ") { showPicker = true }
                        .buttonStyle(PuffyStyle(color: hasTargets ? .white : .blue, height: 38, fullWidth: false, strong: !hasTargets))
                        .disabled(!authorized)
                        .opacity(authorized ? 1 : 0.5)
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "paperplane.fill").foregroundColor(DP.pink).font(.system(size: 12))
                    Text("インスタは「アプリ」だけ選んでね。instagram.com（サイト）まで選ぶと、DMも開けなくなるよ")
                        .font(.dp(12, .bold)).foregroundColor(DP.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)

                if authorized && hasTargets {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 22)).foregroundColor(DP.green)
                        Text("これで「時間を取り戻す」中と、夜のおやすみロック中に ブロックされるよ").font(.dp(13, .bold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.green.opacity(0.12)))
                }

                if let m = message {
                    Text(m).font(.dp(13, .bold)).foregroundColor(DP.yellow)
                }

                Text("SNSのアプリ（インスタ・TikTok・YouTube・Xなど）や「SNS」カテゴリをえらんでね。")
                    .font(.dp(12, .medium)).foregroundColor(DP.dim)
                    .fixedSize(horizontal: false, vertical: true)

                Button { showDM = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "paperplane.fill").foregroundColor(DP.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("インスタのDMだけ開く").font(.dp(14, .heavy)).foregroundColor(.white)
                            Text("リールは出ないブラウザ版。初回だけログインが必要").font(.dp(11, .bold)).foregroundColor(DP.gray)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(DP.dim)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
                }
                .buttonStyle(PressStyle(scale: 0.97))
                .padding(.top, 10)
            }
            .padding(20)
        }
        .background(DP.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onChange(of: selection) { s in
            SharedSettings.selection = s
            UserDefaults.standard.removeObject(forKey: "p.nightEvents")   // 夜ふかし計測も選びなおしたアプリで
            NightLock.apply()
            Haptic.success()
        }
        .sheet(isPresented: $showDM) { InstagramDMView() }
    }

    private func step<Trailing: View>(_ n: Int, done: Bool, title: String, sub: String,
                                      @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "\(n).circle")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(done ? DP.green : DP.gray)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.dp(15, .heavy))
                Text(sub).font(.dp(12, .bold)).foregroundColor(DP.gray)
            }
            Spacer(minLength: 0)
            trailing()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
    }

    private func authorize() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorized = NightLock.isAuthorized
            if authorized { Haptic.success() }
        } catch {
            message = "許可できなかったよ。設定アプリ → スクリーンタイム がオンか確認してね"
        }
    }
}

/// インスタのDM（ブラウザ版）。アプリをブロックしていても開ける
enum InstagramDM {
    static let url = URL(string: "https://www.instagram.com/direct/inbox/")!
}

/// DMを開いている間だけ、サイト（webDomains / webDomainCategories）の遮断を外す。アプリの遮断はそのまま
enum DMGate {
    private static let flag = "p.dmOpen"
    /// いまDM画面が出ているか（アプリに戻ってきたとき、また外すため）
    static var visible = false

    static func open() {
        visible = true
        #if !DEMO
        UserDefaults.standard.set(true, forKey: flag)
        // アプリを止めると、そのアプリのサイト（instagram.com）もiOSが止めることがある。
        // DM画面を出している間だけ、ドパ抜きが使う全ストアの遮断を外す（閉じる・アプリを離れると すぐ戻す）
        for name in [ManagedSettingsStore.Name("session"), .nightBlock] {
            let store = ManagedSettingsStore(named: name)
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            store.shield.webDomains = nil
            store.shield.webDomainCategories = nil
            store.webContent.blockedByFilter = nil
        }
        // 前のバージョンのストアと、名前なしのストアは もう使わないので ぜんぶ消す
        ManagedSettingsStore(named: .dailyLimit).clearAllSettings()
        ManagedSettingsStore(named: .always).clearAllSettings()
        ManagedSettingsStore().clearAllSettings()
        #endif
    }

    /// DMを閉じた・アプリを離れた・起動したとき：もとに戻す
    static func close() {
        #if !DEMO
        guard UserDefaults.standard.bool(forKey: flag) else { return }
        UserDefaults.standard.set(false, forKey: flag)
        if UserDefaults.standard.object(forKey: "p.sStart") != nil { SessionShield.on() }
        if SharedSettings.nightBlockEnabled && NightLock.isReady && NightLock.isSleepTime() { Blocker.block(.nightBlock) }
        #endif
    }
}

/// DM画面（開いている間だけサイトの遮断を外す）
/// 遮断を外してから反映されるまで少し待って、それから開く（先に開くと制限ページのままになる）
struct InstagramDMView: View {
    @State private var ready = false

    var body: some View {
        ZStack {
            if ready {
                SafariView(url: InstagramDM.url).ignoresSafeArea()
            } else {
                VStack(spacing: 14) {
                    DogView(size: 90, mood: .happy)
                    ProgressView().tint(.white)
                    Text("DMをひらくよ…").font(.dp(14, .heavy)).foregroundColor(DP.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DP.bg.ignoresSafeArea())
            }
        }
        .onAppear {
            DMGate.open()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { ready = true }
        }
        .onDisappear { DMGate.visible = false; DMGate.close() }
    }
}
