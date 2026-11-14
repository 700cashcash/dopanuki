import SwiftUI

enum DPTab: Int, CaseIterable {
    case room, friends, breath, lesson, goals

    var icon: String {
        switch self {
        case .room: return "house"
        case .friends: return "person.2"
        case .breath: return "smallcircle.filled.circle"
        case .lesson: return "play.rectangle"
        case .goals: return "flag"
        }
    }
    var selectedIcon: String {
        switch self {
        case .room: return "house.fill"
        case .friends: return "person.2.fill"
        case .breath: return "smallcircle.filled.circle.fill"
        case .lesson: return "play.rectangle.fill"
        case .goals: return "flag.fill"
        }
    }
    var label: String {
        switch self {
        case .room: return "部屋"
        case .friends: return "友達"
        case .breath: return "深呼吸"
        case .lesson: return "レッスン"
        case .goals: return "やりたいこと"
        }
    }
}

/// アプリの一番外側：画面＋下のタブ（アイコンだけの黒いバー）
struct ProtoRoot: View {
    @StateObject private var game = GameState()
    @State private var tab: DPTab = .room
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch tab {
            case .room: RoomView(tab: $tab)
            case .friends: FriendsView()
            case .breath: BreathView()
            case .lesson: LessonListView()
            case .goals: GoalsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) { DPTabBar(tab: $tab) }
        .background(DP.bg.ignoresSafeArea())
        .environmentObject(game)
        .onAppear { game.checkNight() }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: Binding(get: { game.flow != nil },
                                              set: { if !$0 { game.flow = nil } })) {
            SessionFlowView().environmentObject(game)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { game.checkNight(); game.clock = Date() }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { game.clock = $0 }
        // おやすみロック：夜は基地に置くまで すすめない
        .overlay {
            if game.needsNightBase {
                NightBaseView().environmentObject(game).transition(.opacity)
            }
        }
        #if DEBUG
        // スクショ確認用: -debugTab 0〜4 / -debugPick YES
        .onAppear {
            let d = UserDefaults.standard
            if d.object(forKey: "debugTab") != nil, let tt = DPTab(rawValue: d.integer(forKey: "debugTab")) { tab = tt }
            if d.bool(forKey: "debugPick") && game.flow == nil { game.flow = .pick }
            if d.bool(forKey: "debugBase") && game.flow == nil { game.start(SessionPlan(title: "25分", goalMinutes: 25)) }
            if d.bool(forKey: "debugNight") { game.nightToast = "おはよう！ねてる間に7時間取り戻したよ" }
            if d.bool(forKey: "debugNoNightBase") { game.nightBaseSkipped = true }
            if d.bool(forKey: "debugPeek") && game.flow == nil {
                game.start(SessionPlan(title: "25分", goalMinutes: 25, lives: 3, peekMinutes: 5, useBase: false))
                game.demoBoost = 8 * 60 + 21; game.lives = 3
                game.peek(minutes: 10, reason: "LINEの返信")
            }
            if d.bool(forKey: "debugResult") {
                game.flow = .result(SessionResult(minutes: 42, bones: 1, stars: 76, multiplier: 1.5, baseBonus: true, declared: true))
            }
            if d.bool(forKey: "debugDeclare") && game.flow == nil {
                var p = SessionPlan(title: "3時間", goalMinutes: 180, useBase: false)
                p.declared = true
                p.cardWhen = "21:30まで"
                game.start(p)
            }
            if d.bool(forKey: "debugRun") && game.flow == nil {
                game.start(SessionPlan(title: "25分", goalMinutes: 25, lives: 2, peekMinutes: 5)); game.begin(atBase: true)
            }
        }
        #endif
    }
}

struct DPTabBar: View {
    @Binding var tab: DPTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DPTab.allCases, id: \.self) { t in
                Button {
                    if tab != t { Haptic.select() }
                    tab = t
                } label: {
                    Image(systemName: tab == t ? t.selectedIcon : t.icon)
                        .font(.system(size: 23, weight: tab == t ? .bold : .regular))
                        .foregroundColor(tab == t ? .white : Color(hex: 0xA8A8A8))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle(scale: 0.86))
                .accessibilityLabel(Text(t.label))
            }
        }
        .padding(.horizontal, 8)
        .background(Color.black.ignoresSafeArea(edges: .bottom))
        .overlay(Rectangle().fill(DP.line).frame(height: 1), alignment: .top)
    }
}
