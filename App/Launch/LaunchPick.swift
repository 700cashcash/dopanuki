import SwiftUI

/// 置く：何する？（一言）→ 時間 → 宣言して開始
struct LaunchPickView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var life: LifeState
    @State private var purpose = ""
    @State private var custom = ""
    @State private var night = false
    @AppStorage("p.lenUnit") private var unitRaw = 0
    @AppStorage("p.lenValue") private var value: Double = 25
    @State private var showSettings = false
    @FocusState private var typing: Bool

    private var unit: LengthUnit { LengthUnit(rawValue: unitRaw) ?? .minute }
    private var chosen: String {
        let c = custom.trimmingCharacters(in: .whitespaces)
        return c.isEmpty ? purpose : c
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button { game.cancelPick() } label: { CircleIcon(system: "xmark") }
                    .buttonStyle(PressStyle()).accessibilityLabel(Text("とじる"))
                Spacer()
            }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 10) {
                        DogView(size: 64, alive: true)
                        Bubble(text: "取り戻した時間で、何する？")
                    }

                    // 何する？
                    FlowChips(items: life.purposes, selected: purpose) { p in
                        Haptic.select()
                        purpose = purpose == p ? "" : p
                        custom = ""
                        typing = false
                    }
                    TextField("ほかに書く（例：英単語）", text: $custom)
                        .font(.dp(15, .bold))
                        .focused($typing)
                        .submitLabel(.done)
                        .padding(.horizontal, 14).frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(DP.card))
                        .onChange(of: custom) { v in if !v.isEmpty { purpose = "" } }

                    // 時間
                    Text("どのくらい？").font(.dp(16, .heavy))
                    lengthPicker
                }
                .padding(.bottom, 10)
            }

            if needsSetup {
                Button { showSettings = true } label: { Label("時間を食べるアプリを えらぶ", systemImage: "gearshape.fill") }
                    .buttonStyle(PuffyStyle(color: .yellow, height: 58))
            } else {
                Button { start() } label: { Label("宣言してはじめる", systemImage: "megaphone.fill") }
                    .buttonStyle(PuffyStyle(color: .blue, height: 60))
            }
            Text(chosen.isEmpty ? "何する？は スキップしてもOK" : "「\(chosen)」で \(title)")
                .font(.dp(12, .bold)).foregroundColor(DP.gray).frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(TopGlow(color: DP.navy, reach: 0.4))
        .sheet(isPresented: $showSettings) { BlockSettingsView() }
        .onAppear { if purpose.isEmpty && custom.isEmpty { purpose = life.todayGoal } }
    }

    private var needsSetup: Bool {
        #if DEMO
        return false
        #else
        _ = showSettings
        return !(NightLock.isAuthorized && NightLock.hasTargets)
        #endif
    }

    private var title: String { night ? "あしたの朝まで" : unit.title(Int(value)) }

    private var goalMinutes: Int {
        if night {
            let cal = Calendar.current
            var t = cal.date(bySettingHour: SharedSettings.nightEndHour, minute: 0, second: 0, of: Date()) ?? Date()
            if t <= Date() { t = t.addingTimeInterval(86400) }
            return max(1, Int(t.timeIntervalSinceNow / 60))
        }
        return Int(value) * unit.perUnit
    }

    private func start() {
        var p = SessionPlan(title: title, goalMinutes: goalMinutes, lives: 99, peekMinutes: 5, useBase: false)
        p.purpose = chosen
        p.declared = true
        p.cardWhen = night ? "あしたの朝まで" : SessionPickView.whenText(minutes: goalMinutes, unit: unit, value: Int(value))
        life.remember(purpose: custom)
        if !chosen.isEmpty && life.todayGoal.isEmpty { life.setTodayGoal(chosen) }
        game.start(p)
    }

    private var lengthPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(LengthUnit.allCases, id: \.rawValue) { u in
                    Button {
                        Haptic.select()
                        night = false
                        unitRaw = u.rawValue
                        value = min(max(value, u.range.lowerBound), u.range.upperBound)
                        if u == .minute { value = max(5, (value / 5).rounded() * 5) }
                    } label: { Chip(label: u.label, on: !night && unit == u).fixedSize() }
                    .buttonStyle(PressStyle())
                }
                Spacer(minLength: 0)
                Button { Haptic.select(); night = true } label: {
                    Label("朝まで", systemImage: "moon.fill").font(.dp(13, .heavy)).lineLimit(1).fixedSize()
                }
                .buttonStyle(PuffyStyle(color: night ? .purple : .white, height: 36, fullWidth: false, strong: night))
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if night {
                    Text("あしたの朝まで").font(.dp(30, .heavy))
                } else {
                    Text("\(Int(value))").font(.num(48))
                    Text(unit == .week ? "週間" : unit.label).font(.dp(20, .heavy))
                }
                Spacer()
            }
            if !night {
                Slider(value: $value, in: unit.range, step: unit.step)
                    .tint(DP.blue)
                    .onChange(of: value) { _ in Haptic.select() }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
    }
}

/// 折り返すチップ（iOS 16：横に並べて、はみ出たら次の行）
struct FlowChips: View {
    let items: [String]
    let selected: String
    let tap: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { p in
                Button { tap(p) } label: { Chip(label: p, on: p == selected).fixedSize() }
                    .buttonStyle(PressStyle())
            }
        }
    }
}

/// iOS 16 の Layout で、左から詰めて折り返す
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width && x > 0 { x = 0; y += row + spacing; row = 0 }
            x += s.width + spacing
            row = max(row, s.height)
        }
        return CGSize(width: width, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX && x > bounds.minX { x = bounds.minX; y += row + spacing; row = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            row = max(row, s.height)
        }
    }
}
