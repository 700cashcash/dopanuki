import SwiftUI

/// ごほうびの道：深呼吸10分ごとに、景色と音がひらく
struct RoadView: View {
    @EnvironmentObject var game: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var pulse = false

    private var next: RoadReward? { Road.next(after: game.breathMinutes) }

    var body: some View {
        ZStack {
            DP.bg.ignoresSafeArea()
            TopGlow(color: DP.purple.opacity(0.6), reach: 0.4)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack {
                        Button { dismiss() } label: { CircleIcon(system: "xmark") }.buttonStyle(PressStyle())
                        Spacer()
                        Text("深呼吸 合計 \(game.breathMinutes)分").font(.num(14))
                            .padding(.horizontal, 12).frame(height: 32)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                    }
                    Text("ごほうびの道").font(.dp(28, .heavy))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                    Text("10分すうごとに、景色と音がひらくよ").font(.dp(13, .bold)).foregroundColor(DP.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 20)

                    stop(icon: "flag.fill", title: "スタート", sub: "はじめからの景色 4つ", state: .open, index: -1)
                    ForEach(Array(Road.all.enumerated()), id: \.element.id) { i, r in
                        stop(icon: r.icon, title: r.name, sub: "\(r.minutes)分",
                             state: r.minutes <= game.breathMinutes ? .open : (r == next ? .next : .locked), index: i)
                    }
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever()) { pulse = true } }
    }

    private enum StopState { case open, next, locked }

    /// ジグザグにならぶ まる
    private func stop(icon: String, title: String, sub: String, state: StopState, index: Int) -> some View {
        let x: CGFloat = [0, 70, 0, -70][(index + 4) % 4]
        let here = state == .next || (next == nil && index == Road.all.count - 1)
        let color: Color = state == .open ? (index % 2 == 0 ? DP.blue : DP.pink) : (state == .next ? DP.yellow : Color(hex: 0x2E2E2E))
        return VStack(spacing: 6) {
            if index >= 0 {
                Capsule().fill(state == .locked ? Color(hex: 0x2E2E2E) : color.opacity(0.6))
                    .frame(width: 6, height: 26)
            }
            HStack(spacing: 10) {
                if here {
                    DogView(size: 56, mood: .happy).bob(4)
                }
                ZStack {
                    Circle().fill(Color.black.opacity(0.4)).offset(y: 6)
                    Circle().fill(color)
                    Image(systemName: state == .locked ? "lock.fill" : icon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(state == .locked ? DP.dim : (state == .next ? .black : .white))
                }
                .frame(width: 72, height: 72)
                .scaleEffect(state == .next && pulse ? 1.08 : 1)
                .shadow(color: state == .next ? DP.yellow.opacity(0.7) : .clear, radius: pulse ? 18 : 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.dp(15, .heavy)).foregroundColor(state == .locked ? DP.gray : .white)
                    Text(state == .next ? "あと\(nextLeft)分" : sub).font(.dp(12, .bold))
                        .foregroundColor(state == .next ? DP.yellow : DP.gray)
                }
                .frame(width: 110, alignment: .leading)
            }
            .offset(x: x)
        }
        .frame(maxWidth: .infinity)
    }

    private var nextLeft: Int { (next?.minutes ?? 0) - game.breathMinutes }
}

/// いいねしたレッスンカード
struct LikedCardsView: View {
    @EnvironmentObject var game: GameState
    @Environment(\.dismiss) private var dismiss

    private var cards: [(key: String, course: Course, q: LessonQ)] {
        game.likedCards.compactMap { key in
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 2, let c = Courses.all.first(where: { $0.id == parts[0] }),
                  parts[1] < c.questions.count else { return nil }
            return (key, c, c.questions[parts[1]])
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button { dismiss() } label: { CircleIcon(system: "xmark") }.buttonStyle(PressStyle())
                    Spacer()
                }
                Text("いいねしたカード").font(.dp(28, .heavy))
                if cards.isEmpty {
                    Text("レッスンで ♡ をおすと、ここにたまるよ").font(.dp(14, .bold)).foregroundColor(DP.gray)
                        .padding(.top, 20)
                }
                ForEach(cards, id: \.key) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Text(item.q.e1).font(.system(size: 30))
                            .frame(width: 52, height: 52)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(item.q.bg))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.course.emoji + " " + item.course.title).font(.dp(11, .heavy)).foregroundColor(DP.gray)
                            Text(item.q.question).font(.dp(15, .heavy))
                            let a = item.q.options[item.q.answer]
                            Text("こたえ：\(a.0) \(a.1)").font(.dp(13, .heavy)).foregroundColor(DP.green)
                            Text(item.q.why).font(.dp(13, .medium)).foregroundColor(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Button {
                            Haptic.light()
                            withAnimation { game.likedCards.removeAll { $0 == item.key } }
                        } label: {
                            Image(systemName: "heart.fill").font(.system(size: 22, weight: .bold)).foregroundColor(DP.pink)
                        }
                        .buttonStyle(PressStyle(scale: 0.8))
                        .accessibilityLabel(Text("いいねをはずす"))
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DP.card))
                }
            }
            .padding(20)
        }
        .background(DP.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
