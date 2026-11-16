import SwiftUI
import FamilyControls

/// はじめて開いたとき：オープニング → 名前 → スクリーンタイム → 寝る時間 → 最初の3分
struct OnboardingView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var life: LifeState
    @State private var step = 0
    @State private var name = ""
    @State private var authorized = NightLock.isAuthorized
    @State private var selection = SharedSettings.selection
    @State private var showPicker = false
    @State private var bed = SharedSettings.nightStartHour
    @State private var wake = SharedSettings.nightEndHour
    @State private var message: String?

    var body: some View {
        ZStack {
            DP.bg.ignoresSafeArea()
            switch step {
            case 0:
                OpeningView { withAnimation { step = 1 } }
                    .transition(.opacity)
            default:
                page.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: step)
        .preferredColorScheme(.dark)
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onChange(of: selection) { s in
            SharedSettings.selection = s
            UserDefaults.standard.removeObject(forKey: "p.nightEvents")
            Haptic.success()
        }
        .onAppear {
            name = game.dogName
            #if DEBUG
            let d = UserDefaults.standard
            if d.object(forKey: "debugOnbStep") != nil { step = d.integer(forKey: "debugOnbStep") }
            #endif
        }
    }

    @ViewBuilder private var page: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 6) {
                ForEach(1...4, id: \.self) { i in
                    Capsule().fill(i <= step ? Color.white : Color.white.opacity(0.2)).frame(height: 4)
                }
            }
            .padding(.top, 8)

            HStack {
                Spacer()
                DogView(size: 150, mood: step == 4 ? .happy : .normal, alive: true)
                    .bob(4)
                Spacer()
            }
            .padding(.top, 10)

            switch step {
            case 1: nameStep
            case 2: screenTimeStep
            case 3: bedStep
            default: firstStep
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .background(TopGlow(color: DP.purple.opacity(0.6), reach: 0.5))
    }

    // ① 名前
    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Bubble(text: "んま！ ぼくに なまえ、つけて？")
            TextField("ドパ抜きちゃん", text: $name)
                .font(.dp(22, .heavy))
                .submitLabel(.done)
                .padding(.horizontal, 16).frame(height: 56)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DP.card))
            Spacer(minLength: 0)
            Button {
                let n = name.trimmingCharacters(in: .whitespaces)
                game.dogName = n.isEmpty ? "ドパ抜きちゃん" : n
                next()
            } label: { Text("これにする") }
                .buttonStyle(PuffyStyle(color: .blue, height: 58))
        }
    }

    // ② スクリーンタイム → 時間を食べるアプリを1つ
    private var screenTimeStep: some View {
        let has = !(selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty)
        return VStack(alignment: .leading, spacing: 14) {
            Bubble(text: "時間を いちばん食べちゃうアプリ、ひとつ教えて")
            row(1, done: authorized, title: "スクリーンタイムを許可") {
                if !authorized {
                    Button("許可する") { Task { await authorize() } }
                        .buttonStyle(PuffyStyle(color: .blue, height: 38, fullWidth: false))
                }
            }
            row(2, done: has, title: has ? "えらんだ（\(selection.applicationTokens.count + selection.categoryTokens.count)こ）" : "時間を食べるアプリをえらぶ") {
                Button(has ? "えらびなおす" : "えらぶ") { showPicker = true }
                    .buttonStyle(PuffyStyle(color: has ? .white : .blue, height: 38, fullWidth: false, strong: !has))
                    .disabled(!authorized).opacity(authorized ? 1 : 0.5)
            }
            if let m = message { Text(m).font(.dp(12, .bold)).foregroundColor(DP.yellow) }
            Text("インスタは「アプリ」だけ選んでね（DMはドパ抜きから開けるよ）").font(.dp(12, .bold)).foregroundColor(DP.dim)
            Spacer(minLength: 0)
            Button { next() } label: { Text(has ? "つぎへ" : "あとで") }
                .buttonStyle(PuffyStyle(color: has ? .blue : .white, height: 58, strong: has))
        }
    }

    // ③ 寝る時間
    private var bedStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Bubble(text: "いつも なんじに ねる？ その時間は、ぼくもいっしょに ねるね")
            HStack(spacing: 10) {
                hourBox("ねる", $bed)
                Image(systemName: "arrow.right").foregroundColor(DP.gray)
                hourBox("おきる", $wake)
            }
            Text("ねる30分前に、スマホを充電（基地）につなぐよ").font(.dp(12, .bold)).foregroundColor(DP.dim)
            Spacer(minLength: 0)
            Button {
                SharedSettings.nightBlockEnabled = true
                SharedSettings.nightStartHour = bed
                SharedSettings.nightEndHour = wake
                UserDefaults.standard.removeObject(forKey: "p.nightEvents")
                NightLock.apply()
                next()
            } label: { Text("これでOK") }
                .buttonStyle(PuffyStyle(color: .blue, height: 58))
        }
    }

    // ④ 最初の3分
    private var firstStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Bubble(text: "さいしょは 3分だけ。スマホ置いて、ぼくと まってて")
            Text("3分たったら、もどってきてね").font(.dp(14, .bold)).foregroundColor(DP.gray)
            Spacer(minLength: 0)
            Button {
                life.data.onboarded = true
                var p = SessionPlan(title: "3分", goalMinutes: 3, lives: 99, peekMinutes: 5, useBase: false)
                p.purpose = "はじめての3分"
                game.start(p)
            } label: { Label("3分 置いてみる", systemImage: "play.fill") }
                .buttonStyle(PuffyStyle(color: .blue, height: 60))
        }
    }

    private func next() { Haptic.select(); withAnimation { step += 1 } }

    private func row<T: View>(_ n: Int, done: Bool, title: String, @ViewBuilder trailing: () -> T) -> some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "\(n).circle")
                .font(.system(size: 24, weight: .bold)).foregroundColor(done ? DP.green : DP.gray)
            Text(title).font(.dp(15, .heavy))
            Spacer(minLength: 0)
            trailing()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
    }

    private func hourBox(_ label: String, _ hour: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.dp(12, .heavy)).foregroundColor(DP.gray)
            Picker(label, selection: hour) {
                ForEach(0..<24, id: \.self) { h in Text(String(format: "%d:00", h)).tag(h) }
            }
            .pickerStyle(.menu).tint(.white)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
    }

    private func authorize() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorized = NightLock.isAuthorized
        } catch {
            message = "許可できなかったよ（設定アプリ → スクリーンタイム がオンか確認してね）"
        }
    }
}
