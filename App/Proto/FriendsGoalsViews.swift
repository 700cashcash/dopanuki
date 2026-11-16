import SwiftUI
import CoreMotion

// MARK: - 友達

private struct Friend: Identifiable {
    let id = UUID()
    let name: String
    let minutes: Int      // 今週取り戻した時間（分）
    let steps: Int        // きょうの歩数
    let note: String
    let scarf: Color
    let live: Bool
}

/// きょうの歩数（CoreMotion）。許可がない・使えないときは 0
final class StepCounter: ObservableObject {
    @Published var today = 0
    private let pedometer = CMPedometer()

    func refresh() {
        guard CMPedometer.isStepCountingAvailable() else { today = 0; return }
        let start = Calendar.current.startOfDay(for: Date())
        pedometer.queryPedometerData(from: start, to: Date()) { [weak self] data, _ in
            let n = data?.numberOfSteps.intValue ?? 0
            DispatchQueue.main.async { self?.today = n }
        }
    }
}

struct FriendsView: View {
    @EnvironmentObject var game: GameState
    @StateObject private var steps = StepCounter()
    @State private var seg = 1   // 0 = いま, 1 = 時間, 2 = 歩数
    @State private var showDM = false

    private let others = [
        Friend(name: "ゆうき", minutes: 27 * 60 + 40, steps: 6200, note: "いま置いてる・42分", scarf: DP.green, live: true),
        Friend(name: "さき", minutes: 18 * 60 + 15, steps: 9800, note: "いま置いてる・15分", scarf: DP.pink, live: true),
        Friend(name: "たくみ", minutes: 14 * 60 + 5, steps: 4100, note: "きのう 3時間ロック", scarf: DP.orange, live: false),
        Friend(name: "あや", minutes: 11 * 60 + 30, steps: 12400, note: "さんぽ 8,000歩", scarf: DP.yellow, live: false),
        Friend(name: "みお", minutes: 6 * 60 + 20, steps: 2300, note: "3日ぶり", scarf: DP.violet, live: false),
    ]

    private var me: Friend {
        Friend(name: "あなた", minutes: game.weekMinutes, steps: steps.today,
               note: "きょう \(game.todayMinutes)分 ・ \(steps.today.formatted())歩", scarf: DP.blue, live: game.sessionStart != nil)
    }
    private func score(_ f: Friend) -> Int { seg == 2 ? f.steps : f.minutes }
    private func scoreText(_ f: Friend) -> String {
        seg == 2 ? f.steps.formatted() + "歩" : "\(f.minutes / 60)h\(f.minutes % 60)m"
    }
    private var ranked: [Friend] { (others + [me]).sorted { score($0) > score($1) } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text(headline)
                    .font(.dp(12, .heavy)).foregroundColor(DP.gray).padding(.top, 52)
                Text(seg == 1 ? "今週のランキング" : (seg == 2 ? "きょうの歩数" : "いま")).font(.dp(28, .heavy))
                HStack(spacing: 8) {
                    Button { Haptic.select(); seg = 0 } label: { Chip(label: "いま", on: seg == 0) }.buttonStyle(PressStyle())
                    Button { Haptic.select(); seg = 1 } label: { Chip(label: "時間", on: seg == 1) }.buttonStyle(PressStyle())
                    Button { Haptic.select(); seg = 2; steps.refresh() } label: { Chip(label: "歩数", on: seg == 2) }.buttonStyle(PressStyle())
                    Spacer()
                    ShareLink(item: "いっしょにスマホ置こ！ #ドパ抜きチャレンジ") {
                        Image(systemName: "person.badge.plus").font(.system(size: 15, weight: .heavy))
                    }
                    .buttonStyle(PuffyStyle(color: .green, height: 40, circle: true, strong: false))
                    .accessibilityLabel(Text("招待"))
                    Button { Haptic.light(); showDM = true } label: {
                        Image(systemName: "paperplane.fill").font(.system(size: 15, weight: .heavy))
                    }
                    .buttonStyle(PuffyStyle(color: .white, height: 40, circle: true, strong: false))
                    .accessibilityLabel(Text("インスタのDMを開く"))
                }
                if seg == 0 { nowList } else { ranking }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(TopGlow(color: Color(hex: 0x1E9E5E).opacity(0.6), reach: 0.35))
        .sheet(isPresented: $showDM) { InstagramDMView() }
        .onAppear {
            steps.refresh()
            #if DEBUG
            if UserDefaults.standard.object(forKey: "debugSeg") != nil { seg = UserDefaults.standard.integer(forKey: "debugSeg") }
            #endif
        }
    }

    private var headline: String {
        switch seg {
        case 1: return "月曜にリセット ・ 取り戻した時間で決まる"
        case 2: return "毎日リセット ・ 歩いた数で決まる"
        default: return "いっしょに置いてる友達"
        }
    }

    private var ranking: some View {
        let r = ranked
        let myRank = (r.firstIndex { $0.name == "あなた" } ?? 0) + 1
        return VStack(alignment: .leading, spacing: 14) {
            ZStack {
                DP.purple
                Blob(color: DP.pink.opacity(0.9), size: 200, period: 10).offset(x: -140, y: -70)
                Blob(color: DP.green.opacity(0.8), size: 180, period: 9, offset: 0.5).offset(x: 150, y: 80)
                HStack(alignment: .bottom, spacing: 8) {
                    podium(r[1], rank: 2, height: 70)
                    podium(r[0], rank: 1, height: 100)
                    podium(r[2], rank: 3, height: 50)
                }
                .padding(.horizontal, 14)
                .padding(.top, 20)
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(spacing: 2) {
                ForEach(3..<r.count, id: \.self) { i in
                    row(r[i], rank: i + 1)
                }
            }

            if myRank > 1 {
                let above = r[myRank - 2]
                HStack(spacing: 12) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 28)).foregroundColor(DP.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(above.name)まで、あと " + gapText(score(above) - score(me) + 1)).font(.dp(15, .heavy))
                        Text(seg == 2 ? "スマホを置いて、さんぽいこ！" : "スマホを置けば、ぬけるよ").font(.dp(12, .medium)).foregroundColor(DP.gray)
                    }
                    Spacer()
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
            }

            Button { game.flow = .pick } label: { Label("時間を取り戻す", systemImage: "play.fill") }
                .buttonStyle(PuffyStyle(color: .blue, height: 58))
        }
    }

    private func gapText(_ n: Int) -> String {
        seg == 2 ? n.formatted() + "歩" : (n >= 60 ? "\(n / 60)時間\(n % 60)分" : "\(n)分")
    }

    private func podium(_ f: Friend, rank: Int, height: CGFloat) -> some View {
        VStack(spacing: 6) {
            if rank == 1 {
                Image(systemName: "crown.fill").foregroundColor(DP.yellow).font(.system(size: 20))
            }
            DogView(size: rank == 1 ? 76 : 62, scarf: f.scarf, blinks: false)
            Text(f.name).font(.dp(13, .heavy))
            Text(scoreText(f)).font(.num(15)).foregroundColor(f.name == "あなた" ? DP.yellow : .white)
                .lineLimit(1).minimumScaleFactor(0.7)
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.18))
                Text("\(rank)").font(.num(26))
            }
            .frame(height: height)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ f: Friend, rank: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)").font(.num(15)).foregroundColor(DP.gray).frame(width: 18)
            DogView(size: 40, scarf: f.scarf, blinks: false)
                .background(Circle().fill(DP.card2))
            VStack(alignment: .leading, spacing: 2) {
                Text(f.name).font(.dp(15, .heavy)).foregroundColor(f.name == "あなた" ? DP.yellow : .white)
                Text(f.note).font(.dp(12, .medium)).foregroundColor(DP.gray)
            }
            Spacer()
            Text(scoreText(f)).font(.num(15))
        }
        .padding(.vertical, 8)
    }

    private var nowList: some View {
        VStack(spacing: 10) {
            ForEach(ranked.filter { $0.live }) { f in
                HStack(spacing: 12) {
                    DogView(size: 52, mood: .sleep, scarf: f.scarf)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(f.name).font(.dp(15, .heavy))
                        HStack(spacing: 5) {
                            Circle().fill(DP.green).frame(width: 7, height: 7)
                            Text(f.note).font(.dp(12, .bold)).foregroundColor(DP.gray)
                        }
                    }
                    Spacer()
                    Button { Haptic.success() } label: { Image(systemName: "hand.thumbsup.fill") }
                        .buttonStyle(PuffyStyle(color: .yellow, height: 44, circle: true, strong: false))
                        .accessibilityLabel(Text("おうえん"))
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
            }
            Button { game.flow = .pick } label: { Label("いっしょに置く", systemImage: "play.fill") }
                .buttonStyle(PuffyStyle(color: .blue, height: 58))
                .padding(.top, 6)
        }
    }
}

// MARK: - やりたいこと

struct GoalsView: View {
    @EnvironmentObject var game: GameState
    @State private var adding = false
    @State private var newTitle = ""
    @State private var popID: UUID?
    @State private var finding = false

    private var doneCount: Int { game.goals.filter { $0.done }.count }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("ぜんぶ かなえよ！").font(.dp(12, .heavy)).foregroundColor(DP.gray).padding(.top, 52)
                Text("やりたいこと").font(.dp(28, .heavy))

                ZStack(alignment: .leading) {
                    Color(hex: 0xE8661E)
                    Blob(color: DP.yellow, size: 180, period: 10).offset(x: 220, y: -40)
                    Blob(color: DP.pink.opacity(0.85), size: 150, period: 8, offset: 0.4).offset(x: 120, y: 60)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("かなえた").font(.dp(12, .heavy)).foregroundColor(.white.opacity(0.85))
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(doneCount)").font(.num(54))
                            Text("/ \(game.goals.count)").font(.num(20)).foregroundColor(.white.opacity(0.8))
                        }
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.3))
                                Capsule().fill(Color.white)
                                    .frame(width: g.size.width * CGFloat(doneCount) / CGFloat(max(1, game.goals.count)))
                            }
                        }
                        .frame(width: 170, height: 6)
                        .animation(.spring(), value: doneCount)
                    }
                    .padding(20)
                    DogView(size: 110, mood: doneCount > 0 ? .happy : .normal)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 14)
                        .bob(5)
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                LikeMaybeCard()

                Button { finding = true } label: { Label("いっしょに探す", systemImage: "sparkles") }
                    .buttonStyle(PuffyStyle(color: .purple, height: 56))

                AlternativesRow()

                FriendGoalsRow()

                Text("リスト").font(.dp(17, .heavy)).padding(.top, 4)
                VStack(spacing: 2) {
                    ForEach(game.goals) { g in goalRow(g) }
                }

                Button { newTitle = ""; adding = true } label: { Label("追加", systemImage: "plus") }
                    .buttonStyle(PuffyStyle(color: .white, height: 54, strong: false))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(TopGlow(color: Color(hex: 0xE8661E).opacity(0.5), reach: 0.35))
        .fullScreenCover(isPresented: $finding) { GoalFinderView().environmentObject(game) }
        #if DEBUG
        .onAppear { if UserDefaults.standard.bool(forKey: "debugFinder") { finding = true } }
        #endif
        .alert("やりたいこと", isPresented: $adding) {
            TextField("例：ギターをひく", text: $newTitle)
            Button("追加") {
                let t = newTitle.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { game.goals.append(Goal(emoji: "✨", title: t, done: false)); Haptic.success() }
            }
            Button("やめる", role: .cancel) {}
        }
    }

    private func goalRow(_ g: Goal) -> some View {
        HStack(spacing: 14) {
            Text(g.emoji).font(.system(size: 26))
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(DP.card2))
            VStack(alignment: .leading, spacing: 3) {
                Text((g.fav ? "★ " : "") + g.title).font(.dp(15, .heavy))
                    .foregroundColor(g.fav ? DP.yellow : .white)
                if let f = FriendGoals.match(g.title), !g.done {
                    Text("\(f.name)も やってるよ").font(.dp(12, .bold)).foregroundColor(DP.pink)
                } else {
                    Text(g.done ? "かなった！" : "取り戻した時間でやる")
                        .font(.dp(12, .bold))
                        .foregroundColor(g.done ? DP.green : DP.gray)
                }
            }
            Spacer()
            if !g.done {
                Button { Haptic.select(); game.tryGoal(g) } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "play.fill").font(.system(size: 10, weight: .heavy))
                        Text("5分").font(.dp(12, .heavy))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10).frame(height: 30)
                    .background(Capsule().fill(DP.blue))
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel(Text("5分だけやってみる"))
            }
            Button { toggle(g) } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.black)
                    .opacity(g.done ? 1 : 0)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(g.done ? DP.green : Color.clear))
                    .overlay(Circle().strokeBorder(g.done ? Color.clear : DP.dim, lineWidth: 2))
                    .scaleEffect(popID == g.id ? 1.25 : 1)
            }
            .buttonStyle(PressStyle(scale: 0.85))
            .accessibilityLabel(Text(g.done ? "もどす" : "かなった"))
        }
        .padding(.vertical, 6)
        .contextMenu {
            if !g.done {
                Button { game.tryGoal(g) } label: { Label("5分だけやってみる", systemImage: "play.fill") }
            }
            Button(role: .destructive) {
                game.goals.removeAll { $0.id == g.id }
            } label: { Label("けす", systemImage: "trash") }
        }
    }

    private func toggle(_ g: Goal) {
        guard let i = game.goals.firstIndex(where: { $0.id == g.id }) else { return }
        game.goals[i].done.toggle()
        if game.goals[i].done {
            Haptic.success()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) { popID = g.id }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { popID = nil }
            }
        } else {
            Haptic.light()
        }
    }
}
