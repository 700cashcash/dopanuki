import SwiftUI

/// スマホの代わりにやること
struct Alternative: Identifiable, Equatable {
    let id: String
    let emoji: String
    let title: String
    let minutes: Int
    let reward: String
    let why: String
    let color: Color
    let when: Set<Int>   // 0 = 朝, 1 = 昼, 2 = 夜（おすすめが上にくる時間帯）
}

enum Alternatives {
    static let all: [Alternative] = [
        Alternative(id: "curtain", emoji: "☀️", title: "カーテンをあける", minutes: 1, reward: "+5 ⭐", why: "朝の光で、からだが目をさますよ", color: DP.orange, when: [0]),
        Alternative(id: "water", emoji: "💧", title: "水を1杯", minutes: 1, reward: "+5 ⭐", why: "のどがかわくと、ついスマホに手がのびるんだ", color: DP.blue, when: [0, 1]),
        Alternative(id: "walk", emoji: "🚶", title: "5分さんぽ", minutes: 5, reward: "🦴", why: "外の空気で、あたまがスッキリするよ", color: Color(hex: 0x1E9E5E), when: [0, 1]),
        Alternative(id: "stretch", emoji: "🙆", title: "ストレッチ3分", minutes: 3, reward: "+10 ⭐", why: "からだがほぐれると、ねむりも深くなるよ", color: DP.pink, when: [1, 2]),
        Alternative(id: "bath", emoji: "🛁", title: "お風呂にゆっくり", minutes: 20, reward: "+30 ⭐", why: "お風呂の1時間後に、ねむくなるよ", color: Color(hex: 0x2F6BD0), when: [2]),
        Alternative(id: "book", emoji: "📖", title: "本を10ページ", minutes: 15, reward: "+20 ⭐", why: "ねる前の本は、SNSよりずっとやさしいよ", color: DP.purple, when: [2]),
        Alternative(id: "diary", emoji: "✏️", title: "日記を3行", minutes: 5, reward: "+10 ⭐", why: "書くと、こころがすこし軽くなるよ", color: Color(hex: 0xE8661E), when: [2]),
        Alternative(id: "breath", emoji: "🌬️", title: "深呼吸1分", minutes: 1, reward: "+10 ⭐", why: "ゆっくり息をすると、そわそわがおさまるよ", color: DP.violet, when: [0, 1, 2]),
        Alternative(id: "tidy", emoji: "🧹", title: "部屋を5分かたづけ", minutes: 5, reward: "+10 ⭐", why: "部屋がととのうと、気持ちもととのうよ", color: Color(hex: 0x3E8F80), when: [1]),
        Alternative(id: "music", emoji: "🎧", title: "好きな音楽を1曲", minutes: 5, reward: "+5 ⭐", why: "目をとじて聴くと、いいリセットになるよ", color: DP.red, when: [1, 2]),
        Alternative(id: "call", emoji: "📞", title: "友達に電話", minutes: 10, reward: "+15 ⭐", why: "声で話すと、タイムラインより元気がでるよ", color: Color(hex: 0xC9A100), when: [1]),
    ]

    static var timeSlot: Int {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<11: return 0
        case 11..<18: return 1
        default: return 2
        }
    }

    /// いまの時間帯にあうものを先に
    static var forNow: [Alternative] {
        let t = timeSlot
        return all.filter { $0.when.contains(t) } + all.filter { !$0.when.contains(t) }
    }
}

/// やりたいこと画面の「おすすめ」カード列
struct AlternativesRow: View {
    @EnvironmentObject var game: GameState
    @State private var picked: Alternative?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("スマホの代わりに").font(.dp(17, .heavy))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Alternatives.forNow) { a in
                        Button { Haptic.select(); picked = a } label: { card(a) }
                            .buttonStyle(PressStyle(scale: 0.95))
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
        .sheet(item: $picked) { a in
            AlternativeSheet(alt: a).environmentObject(game)
                .presentationDetents([.height(330)])
        }
    }

    private func card(_ a: Alternative) -> some View {
        ZStack(alignment: .topLeading) {
            a.color
            Blob(color: Color.white.opacity(0.22), size: 110, period: 9).offset(x: 70, y: -40)
            VStack(alignment: .leading, spacing: 4) {
                Text(a.emoji).font(.system(size: 30))
                Spacer(minLength: 0)
                Text(a.title).font(.dp(15, .black)).foregroundColor(.white)
                    .lineLimit(2).multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    Text("\(a.minutes)分").font(.num(12)).foregroundColor(.white.opacity(0.85))
                    Text(a.reward).font(.num(12)).foregroundColor(DP.yellow)
                }
            }
            .padding(12)
        }
        .frame(width: 128, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct AlternativeSheet: View {
    let alt: Alternative
    @EnvironmentObject var game: GameState
    @Environment(\.dismiss) private var dismiss

    private var added: Bool { game.goals.contains { $0.title == alt.title } }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                DogView(size: 70, mood: .happy)
                VStack(alignment: .leading, spacing: 4) {
                    Text(alt.emoji + " " + alt.title).font(.dp(18, .heavy))
                    Text(alt.why).font(.dp(13, .bold)).foregroundColor(DP.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            Button {
                dismiss()
                game.log("alt:" + alt.title)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    game.start(SessionPlan(title: alt.title, goalMinutes: alt.minutes,
                                           lives: game.maxLives, peekMinutes: game.peekMinutes, useBase: game.useBase))
                }
            } label: { Label("やってみる（\(alt.minutes)分）", systemImage: "play.fill") }
                .buttonStyle(PuffyStyle(color: .blue, height: 56))
            Button {
                if !added {
                    game.goals.append(Goal(emoji: alt.emoji, title: alt.title, done: false))
                    Haptic.success()
                }
                dismiss()
            } label: { Text(added ? "やりたいことに追加ずみ" : "やりたいことに追加") }
                .buttonStyle(PuffyStyle(color: .white, height: 50, strong: false))
                .disabled(added)
        }
        .padding(20)
        .background(DP.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
