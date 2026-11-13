import SwiftUI

// MARK: - やりたいこと さがし（スワイプ）

struct Idea: Identifiable, Equatable {
    let id: Int
    let emoji: String
    let title: String
    let cat: String
}

enum Ideas {
    static let cats: [String: Color] = [
        "つくる": DP.orange, "からだ": Color(hex: 0x1E9E5E), "まなぶ": DP.blue,
        "人と": DP.pink, "そと": Color(hex: 0x2F9FB0), "しごと/ゆめ": DP.purple,
    ]
    private static let raw: [(String, String, String)] = [
        ("🎸", "ギターをひく", "つくる"), ("🍞", "パンを焼く", "つくる"), ("✏️", "漫画をかく", "つくる"),
        ("👕", "古着をリメイク", "つくる"), ("📷", "フィルムで写真", "つくる"), ("🧶", "あみものをする", "つくる"),
        ("🎹", "ピアノで1曲", "つくる"),
        ("🏃", "5km走る", "からだ"), ("🧘", "ヨガをする", "からだ"), ("🏊", "泳ぎにいく", "からだ"),
        ("🧗", "ボルダリング", "からだ"), ("💃", "ダンスをおぼえる", "からだ"), ("🚴", "自転車で遠出", "からだ"),
        ("🇰🇷", "韓国語であいさつ", "まなぶ"), ("🗣️", "英語で話す", "まなぶ"), ("📚", "本を月1冊", "まなぶ"),
        ("💻", "プログラミング", "まなぶ"), ("🌍", "世界史をしる", "まなぶ"), ("🧪", "資格をとる", "まなぶ"),
        ("✉️", "友達に手紙", "人と"), ("🍳", "家族にごはん", "人と"), ("🎲", "ボードゲーム会", "人と"),
        ("☕", "カフェで語る", "人と"), ("🎤", "カラオケで新曲", "人と"), ("🤝", "ボランティア", "人と"),
        ("🌌", "星を見に行く", "そと"), ("⛺", "キャンプ", "そと"), ("🗻", "山にのぼる", "そと"),
        ("🚃", "知らない駅でおりる", "そと"), ("🌸", "公園でピクニック", "そと"), ("✈️", "ひとり旅", "そと"),
        ("🎣", "釣りをする", "そと"),
        ("📹", "YouTubeで発信", "しごと/ゆめ"), ("🛍️", "ネットでお店", "しごと/ゆめ"), ("📝", "ブログを書く", "しごと/ゆめ"),
        ("🎨", "作品を売る", "しごと/ゆめ"), ("💼", "インターン", "しごと/ゆめ"), ("🎙️", "ポッドキャスト", "しごと/ゆめ"),
        ("📈", "お金の勉強", "しごと/ゆめ"), ("🏆", "コンテストに出る", "しごと/ゆめ"),
    ]
    static let all: [Idea] = raw.enumerated().map { Idea(id: $0.offset, emoji: $0.element.0, title: $0.element.1, cat: $0.element.2) }
}

struct GoalFinderView: View {
    @EnvironmentObject var game: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var deck: [Idea] = Array(Ideas.all.shuffled().prefix(10))
    @State private var liked: [Idea] = []
    @State private var drag: CGSize = .zero
    @State private var picked: Set<Int> = []
    @State private var count = 0

    private var finished: Bool { count >= 10 || deck.isEmpty }

    var body: some View {
        ZStack {
            DP.bg.ignoresSafeArea()
            TopGlow(color: DP.purple.opacity(0.6), reach: 0.45)
            VStack(spacing: 16) {
                HStack {
                    Button { dismiss() } label: { CircleIcon(system: "xmark") }.buttonStyle(PressStyle())
                    Spacer()
                    if !finished { Text("\(count + 1)/10").font(.num(14)).foregroundColor(DP.gray) }
                }
                if finished { result } else { swiping }
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
    }

    private var swiping: some View {
        VStack(spacing: 18) {
            Text("やってみたい？").font(.dp(28, .heavy)).frame(maxWidth: .infinity, alignment: .leading)
            ZStack {
                ForEach(Array(deck.prefix(3).enumerated().reversed()), id: \.element.id) { i, idea in
                    card(idea)
                        .scaleEffect(i == 0 ? 1 : 1 - CGFloat(i) * 0.05)
                        .offset(y: CGFloat(i) * 14)
                        .offset(i == 0 ? drag : .zero)
                        .rotationEffect(.degrees(i == 0 ? Double(drag.width / 18) : 0))
                        .overlay(alignment: .topLeading) {
                            if i == 0 && drag.width > 30 { stamp("やってみたい", DP.green).rotationEffect(.degrees(-12)).padding(24) }
                        }
                        .overlay(alignment: .topTrailing) {
                            if i == 0 && drag.width < -30 { stamp("ちがう", DP.red).rotationEffect(.degrees(12)).padding(24) }
                        }
                        .gesture(i == 0 ? DragGesture()
                            .onChanged { drag = $0.translation }
                            .onEnded { v in
                                if v.translation.width > 110 { swipe(true) }
                                else if v.translation.width < -110 { swipe(false) }
                                else { withAnimation(.spring()) { drag = .zero } }
                            } : nil)
                }
            }
            .frame(maxHeight: .infinity)
            HStack(spacing: 40) {
                Button { swipe(false) } label: { Image(systemName: "xmark").font(.system(size: 24, weight: .heavy)) }
                    .buttonStyle(PuffyStyle(color: .white, height: 70, circle: true, strong: false))
                    .accessibilityLabel(Text("ちがう"))
                Button { swipe(true) } label: { Image(systemName: "heart.fill").font(.system(size: 26, weight: .heavy)) }
                    .buttonStyle(PuffyStyle(color: .yellow, height: 70, circle: true))
                    .accessibilityLabel(Text("やってみたい"))
            }
        }
    }

    private func card(_ idea: Idea) -> some View {
        let c = Ideas.cats[idea.cat] ?? DP.blue
        return ZStack {
            c
            Blob(color: Color.white.opacity(0.22), size: 260, period: 10).offset(x: 110, y: -150)
            Blob(color: Color.black.opacity(0.12), size: 220, period: 12, offset: 0.4).offset(x: -120, y: 170)
            VStack(spacing: 14) {
                Text(idea.cat).font(.dp(13, .heavy)).foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 12).frame(height: 28)
                    .background(Capsule().fill(Color.black.opacity(0.2)))
                Text(idea.emoji).font(.system(size: 110))
                Text(idea.title).font(.dp(30, .black)).foregroundColor(.white).multilineTextAlignment(.center)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 440)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 12)
    }

    private func stamp(_ text: String, _ color: Color) -> some View {
        Text(text).font(.dp(22, .black)).foregroundColor(color)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color, lineWidth: 4))
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.35)))
    }

    private func swipe(_ yes: Bool) {
        guard let top = deck.first else { return }
        if yes { Haptic.success(); liked.append(top); picked.insert(top.id) } else { Haptic.light() }
        withAnimation(.easeIn(duration: 0.25)) { drag = CGSize(width: yes ? 600 : -600, height: 40) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            deck.removeFirst()
            drag = .zero
            withAnimation(.spring()) { count += 1 }
        }
    }

    private var topCat: String? {
        let counts = Dictionary(grouping: liked, by: { $0.cat }).mapValues { $0.count }
        return counts.max { $0.value < $1.value }?.key
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                DogView(size: 90, mood: .happy).bob(6)
                Bubble(text: topCat.map { "\($0)系が好きなのかも！" } ?? "ピンとくるの、なかったね。またさがそ！")
            }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(liked) { idea in
                        Button {
                            Haptic.select()
                            if picked.contains(idea.id) { picked.remove(idea.id) } else { picked.insert(idea.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Text(idea.emoji).font(.system(size: 26))
                                    .frame(width: 48, height: 48)
                                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Ideas.cats[idea.cat] ?? DP.card2))
                                Text(idea.title).font(.dp(15, .heavy)).foregroundColor(.white)
                                Spacer()
                                Image(systemName: picked.contains(idea.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 24)).foregroundColor(picked.contains(idea.id) ? DP.green : DP.dim)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
                        }
                        .buttonStyle(PressStyle(scale: 0.97))
                    }
                }
            }
            Button {
                for idea in liked where picked.contains(idea.id) && !game.goals.contains(where: { $0.title == idea.title }) {
                    game.goals.append(Goal(emoji: idea.emoji, title: idea.title, done: false))
                }
                Haptic.success()
                dismiss()
            } label: { Label(picked.isEmpty ? "とじる" : "やりたいことに追加（\(picked.count)）", systemImage: "plus") }
                .buttonStyle(PuffyStyle(color: .purple, height: 58))
        }
    }
}

// MARK: - 友達のやりたいこと

struct FriendGoal: Identifiable {
    let id: String
    let name: String
    let scarf: Color
    let emoji: String
    let title: String
    let done: Bool
}

enum FriendGoals {
    static let all = [
        FriendGoal(id: "yuki", name: "ゆうき", scarf: DP.green, emoji: "🎸", title: "ギターで1曲ひく", done: true),
        FriendGoal(id: "saki", name: "さき", scarf: DP.pink, emoji: "🇰🇷", title: "韓国語であいさつ", done: false),
        FriendGoal(id: "takumi", name: "たくみ", scarf: DP.orange, emoji: "🏃", title: "5km走る", done: false),
        FriendGoal(id: "aya", name: "あや", scarf: DP.yellow, emoji: "🍞", title: "パンを焼く", done: true),
    ]
    static func match(_ title: String) -> FriendGoal? { all.first { $0.title == title } }
}

struct FriendGoalsRow: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("友達のやりたいこと").font(.dp(17, .heavy))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(FriendGoals.all) { f in card(f) }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }

    private func card(_ f: FriendGoal) -> some View {
        let added = game.goals.contains { $0.title == f.title }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                DogView(size: 34, scarf: f.scarf, blinks: false)
                Text(f.name).font(.dp(13, .heavy))
                Spacer(minLength: 0)
                if f.done {
                    Text("★かなった").font(.dp(10, .heavy)).foregroundColor(DP.yellow)
                }
            }
            Text(f.emoji + " " + f.title).font(.dp(14, .heavy)).lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)
            Button {
                guard !added else { return }
                game.goals.append(Goal(emoji: f.emoji, title: f.title, done: false))
                Haptic.success()
            } label: { Text(added ? "追加ずみ" : "わたしも") }
                .buttonStyle(PuffyStyle(color: added ? .white : .green, height: 36, strong: !added))
                .disabled(added)
                .opacity(added ? 0.6 : 1)
        }
        .padding(12)
        .frame(width: 170)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DP.card))
    }
}

// MARK: - これ好きかも

struct LikeMaybeCard: View {
    @EnvironmentObject var game: GameState

    /// 記録からいちばん多いものをさがす（★すき は重め）
    private var top: (label: String, emoji: String, title: String)? {
        var score: [String: Int] = [:]
        for (k, v) in game.activity {
            let parts = k.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let w = parts[0] == "fav" ? 3 : 1
            let key = parts[0] == "fav" ? "goal:" + parts[1] : k
            score[key, default: 0] += v * w
        }
        guard let best = score.max(by: { $0.value < $1.value }), best.value >= 2 else { return nil }
        let parts = best.key.split(separator: ":", maxSplits: 1).map(String.init)
        let title = parts[1]
        switch parts[0] {
        case "lesson": return ("「\(title)」のレッスンをしてる", "📖", title)
        case "alt":
            let e = Alternatives.all.first { $0.title == title }?.emoji ?? "✨"
            return ("「\(title)」をしてる", e, title)
        default:
            let e = game.goals.first { $0.title == title }?.emoji ?? "✨"
            return ("「\(title)」をしてる", e, title)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            DogView(size: 64, mood: top == nil ? .normal : .happy)
            VStack(alignment: .leading, spacing: 8) {
                Text("これ好きかも").font(.dp(12, .heavy)).foregroundColor(DP.yellow)
                if let t = top {
                    Text("\(t.label)とき、たのしそうだったよ！これ好きかも？").font(.dp(15, .heavy))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        if !game.goals.contains(where: { $0.title == t.title }) {
                            Button {
                                game.goals.insert(Goal(emoji: t.emoji, title: t.title, done: false), at: 0)
                                Haptic.success()
                            } label: { Text("やりたいことに追加") }
                                .buttonStyle(PuffyStyle(color: .white, height: 38, fullWidth: false, strong: false))
                        }
                        Button {
                            game.start(SessionPlan(title: t.title, goalMinutes: 5, lives: game.maxLives,
                                                   peekMinutes: game.peekMinutes, useBase: game.useBase))
                        } label: { Text("もっとやる") }
                            .buttonStyle(PuffyStyle(color: .blue, height: 38, fullWidth: false))
                    }
                } else {
                    Text("もうすこし記録がたまったら、教えるね").font(.dp(14, .bold)).foregroundColor(DP.gray)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DP.card))
    }
}
