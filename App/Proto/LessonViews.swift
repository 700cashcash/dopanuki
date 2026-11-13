import SwiftUI

struct LessonQ {
    let e1: String, e2: String
    let question: String
    let options: [(String, String)]
    let answer: Int
    let why: String
    let bg: Color, b1: Color, b2: Color
}

struct Course: Identifiable {
    let id: Int
    let emoji: String
    let title: String
    let color: Color
    let questions: [LessonQ]
}

enum Courses {
    static let all: [Course] = [
        Course(id: 0, emoji: "🌙", title: "ぐっすり眠る", color: DP.purple, questions: [
            LessonQ(e1: "🌙", e2: "💭", question: "ねむれない夜、どうする？", options: [("📱", "スマホ"), ("🛁", "お風呂"), ("🍜", "夜食")], answer: 1,
                    why: "お風呂の1時間後に、ねむくなるよ", bg: DP.purple, b1: DP.pink, b2: DP.green),
            LessonQ(e1: "🕯️", e2: "✨", question: "ねる前の部屋は？", options: [("💡", "明るい"), ("🕯️", "うす暗い"), ("📺", "テレビ")], answer: 1,
                    why: "暗いと、からだが夜モードに", bg: Color(hex: 0xE8661E), b1: DP.yellow, b2: DP.pink),
            LessonQ(e1: "🏠", e2: "📱", question: "スマホはどこに置く？", options: [("🛏️", "まくら"), ("👖", "ポケット"), ("🏠", "基地")], answer: 2,
                    why: "遠いほど、ぐっすり！", bg: Color(hex: 0x1E9E5E), b1: DP.green, b2: DP.blue),
            LessonQ(e1: "☀️", e2: "✨", question: "朝おきたら、まず？", options: [("☀️", "カーテン"), ("📱", "SNS"), ("😪", "二度寝")], answer: 0,
                    why: "光をあびると、目がさめる", bg: Color(hex: 0x2F6BD0), b1: DP.green, b2: DP.yellow),
            LessonQ(e1: "☕", e2: "💤", question: "ねる前に飲むなら？", options: [("☕", "コーヒー"), ("🥛", "ミルク"), ("🥤", "コーラ")], answer: 1,
                    why: "カフェインは、ねむりのじゃま", bg: Color(hex: 0xE0457B), b1: DP.yellow, b2: DP.purple),
        ]),
        Course(id: 1, emoji: "🎯", title: "集中する", color: DP.blue, questions: [
            LessonQ(e1: "📚", e2: "🔔", question: "勉強中、通知は？", options: [("🔔", "オン"), ("🔕", "オフ"), ("📳", "バイブ")], answer: 1,
                    why: "1回の通知で、集中が20分もどらないことも", bg: Color(hex: 0x2F6BD0), b1: DP.green, b2: DP.pink),
            LessonQ(e1: "⏱️", e2: "🍅", question: "集中のコツは？", options: [("⏳", "ずっと"), ("🍅", "25分＋休憩"), ("🎮", "ながら")], answer: 1,
                    why: "短く区切ると、長くつづく", bg: DP.red, b1: DP.yellow, b2: DP.purple),
            LessonQ(e1: "📱", e2: "👀", question: "スマホは どこに？", options: [("✋", "手元"), ("🎒", "カバン"), ("👀", "見える所")], answer: 1,
                    why: "見えるだけで、脳はスマホを気にしちゃう", bg: Color(hex: 0x1E9E5E), b1: DP.blue, b2: DP.yellow),
        ]),
    ]
    static let locked = [("🧘", "習慣をつくる"), ("💕", "デート"), ("🌱", "じぶんを知る")]
}

/// 「いま、なにに悩んでる？」の選択肢 → おすすめコース
enum Worries {
    struct Item { let label: String; let emoji: String; let reply: String; let course: Int?; let locked: String? }
    static let all: [Item] = [
        Item(label: "ねむれない", emoji: "🌙", reply: "夜ってスマホ見ちゃうよね。いっしょに ぐっすり作戦しよ！", course: 0, locked: nil),
        Item(label: "集中できない", emoji: "🎯", reply: "通知が多いと、だれでも集中きれちゃうよ。コツ、教えるね！", course: 1, locked: nil),
        Item(label: "つい見ちゃう", emoji: "📱", reply: "見ちゃうのは あなたのせいじゃないよ。しくみを知ろ！", course: 1, locked: nil),
        Item(label: "そわそわする", emoji: "🌀", reply: "そわそわする日もあるよね。まずは深呼吸しよ？", course: nil, locked: "じぶんを知る"),
        Item(label: "やる気が出ない", emoji: "🔋", reply: "ちいさな一歩からでいいよ。もうすぐレッスンできるね！", course: nil, locked: "習慣をつくる"),
    ]
    static func find(_ label: String) -> Item? { all.first { $0.label == label } }
}

/// レッスンのタブ
struct LessonListView: View {
    @EnvironmentObject private var game: GameState
    @State private var playing: Course?
    @State private var showLiked = false

    private var worry: Worries.Item? { Worries.find(game.worry) }
    private var courses: [Course] {
        guard let c = worry?.course else { return Courses.all }
        return Courses.all.sorted { ($0.id == c ? 0 : 1) < ($1.id == c ? 0 : 1) }
    }
    private var locked: [(String, String)] {
        guard let l = worry?.locked else { return Courses.locked }
        return Courses.locked.sorted { ($0.1 == l ? 0 : 1) < ($1.1 == l ? 0 : 1) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("スマホの代わりに").font(.dp(12, .heavy)).foregroundColor(DP.gray).padding(.top, 52)
                Text("レッスン").font(.dp(28, .heavy))
                worryCard
                Button { showLiked = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "heart.fill").font(.system(size: 20, weight: .bold)).foregroundColor(DP.pink)
                            .frame(width: 52, height: 52)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(DP.card2))
                        Text("いいねしたカード（\(game.likedCards.count)）").font(.dp(15, .heavy)).foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(DP.dim)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
                }
                .buttonStyle(PressStyle(scale: 0.97))
                ForEach(courses) { c in
                    Button { playing = c } label: {
                        courseCard(c)
                            .overlay(alignment: .topTrailing) {
                                if worry?.course == c.id { recommendBadge.padding(12) }
                            }
                    }
                    .buttonStyle(PressStyle(scale: 0.97))
                }
                ForEach(locked.indices, id: \.self) { k in
                    let l = locked[k]
                    HStack(spacing: 14) {
                        Text(l.0).font(.system(size: 26))
                            .frame(width: 52, height: 52)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(DP.card2))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(l.1).font(.dp(15, .bold)).foregroundColor(DP.gray)
                            if worry?.locked == l.1 {
                                Text("おすすめ ・ もうすぐ").font(.dp(11, .heavy)).foregroundColor(DP.yellow)
                            }
                        }
                        Spacer()
                        Image(systemName: "lock.fill").foregroundColor(DP.dim)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DP.card))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(TopGlow(color: DP.blue.opacity(0.5), reach: 0.35))
        .fullScreenCover(item: $playing) { c in LessonReelView(course: c).environmentObject(game) }
        .sheet(isPresented: $showLiked) { LikedCardsView().environmentObject(game) }
    }

    private var recommendBadge: some View {
        Text("おすすめ").font(.dp(11, .heavy)).foregroundColor(.black)
            .padding(.horizontal, 10).frame(height: 24)
            .background(Capsule().fill(DP.yellow))
    }

    /// 悩みを聞いて、おすすめを出す
    private var worryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                DogView(size: 54, mood: worry == nil ? .normal : .happy)
                VStack(alignment: .leading, spacing: 4) {
                    Text("いま、なにに悩んでる？").font(.dp(16, .heavy))
                    Text(worry?.reply ?? "えらぶと、ぴったりのレッスンを出すよ")
                        .font(.dp(13, .bold))
                        .foregroundColor(worry == nil ? DP.gray : .white)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, worry == nil ? 0 : 12)
                        .padding(.vertical, worry == nil ? 0 : 8)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(worry == nil ? Color.clear : Color.white.opacity(0.1)))
                        .id(game.worry)
                        .transition(.scale(scale: 0.8, anchor: .topLeading).combined(with: .opacity))
                }
            }
            WrapChips(items: Worries.all.map { $0.emoji + " " + $0.label },
                      selected: worry.map { $0.emoji + " " + $0.label }) { i in
                let w = Worries.all[i]
                Haptic.select()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    game.worry = (game.worry == w.label) ? "" : w.label
                }
            }
            Text("※ 診断や治療のかわりではありません").font(.dp(10, .semibold)).foregroundColor(DP.dim)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DP.card))
    }

    private func courseCard(_ c: Course) -> some View {
        ZStack(alignment: .topLeading) {
            c.color
            Blob(color: DP.pink.opacity(0.9), size: 170, period: 10).offset(x: 200, y: -50)
            Blob(color: DP.green.opacity(0.8), size: 140, period: 8, offset: 0.5).offset(x: 120, y: 70)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(c.questions.count)問 ・ 1分").font(.dp(11, .heavy)).foregroundColor(.white.opacity(0.85))
                Text(c.emoji + " " + c.title).font(.dp(22, .black)).foregroundColor(.white)
                Text("+20 ⭐").font(.num(13)).foregroundColor(DP.yellow)
            }
            .padding(18)
            DogView(size: 90)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 12)
                .offset(y: 10)
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// リール風レッスン：こたえを押したまま、上へスワイプ
struct LessonReelView: View {
    let course: Course
    @EnvironmentObject private var game: GameState
    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var correct = 0
    @State private var dragging = -1
    @State private var dy: CGFloat = 0
    @State private var passed = false
    @State private var toast: (ok: Bool, text: String)?
    @State private var hint = false
    @State private var rewarded = false

    private var done: Bool { index >= course.questions.count }
    private var isLiked: Bool { game.likedCards.contains("\(course.id)-\(index)") }

    var body: some View {
        ZStack {
            if done { endScreen.transition(.opacity) } else { question(course.questions[index]).id(index).transition(.move(edge: .bottom)) }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: index)
        .preferredColorScheme(.dark)
    }

    private func question(_ q: LessonQ) -> some View {
        ZStack {
            q.bg.ignoresSafeArea()
            Blob(color: q.b1.opacity(0.9), size: 300, period: 10).offset(x: -150, y: -260)
            Blob(color: q.b2.opacity(0.85), size: 320, period: 12, offset: 0.4).offset(x: 160, y: 300)

            VStack(spacing: 14) {
                segments
                HStack(spacing: 8) {
                    DogView(size: 30, blinks: false)
                    Text("\(course.emoji) \(course.title)").font(.dp(13, .heavy))
                    Text("\(index + 1)/\(course.questions.count)").font(.num(12)).foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Button { dismiss() } label: { CircleIcon(system: "xmark", size: 36) }.buttonStyle(PressStyle())
                }
                Spacer(minLength: 0)
                HStack(spacing: 18) {
                    Text(q.e1).font(.system(size: 64))
                    Text(q.e2).font(.system(size: 44)).offset(y: -20)
                }
                DogView(size: 120).bob(6)
                Text(q.question)
                    .font(.dp(26, .black))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    ForEach(0..<q.options.count, id: \.self) { i in option(q, i) }
                }
                Text(hintText)
                    .font(.dp(13, .heavy))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 20)

            // いいね（右下）
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        Haptic.light()
                        let key = "\(course.id)-\(index)"
                        if game.likedCards.contains(key) { game.likedCards.removeAll { $0 == key } } else { game.likedCards.append(key) }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(isLiked ? DP.pink : .white)
                            Text("いいね").font(.dp(10, .bold))
                        }
                    }
                    .buttonStyle(PressStyle(scale: 0.8))
                }
                .padding(.trailing, 16)
                .padding(.bottom, 210)
            }

            if let t = toast {
                VStack {
                    Text((t.ok ? "⭕ せいかい！ " : "💡 おしい！ ") + t.text)
                        .font(.dp(14, .heavy))
                        .foregroundColor(t.ok ? .white : Color(hex: 0x2A1C00))
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(Capsule().fill(t.ok ? Color(hex: 0x2E9E6E) : DP.yellow))
                        .padding(.top, 60)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var segments: some View {
        HStack(spacing: 4) {
            ForEach(0..<course.questions.count, id: \.self) { j in
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.3))
                        Capsule().fill(Color.white)
                            .frame(width: g.size.width * (j < index ? 1 : (j == index ? min(1, dy / 80) : 0)))
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.top, 6)
    }

    private var hintText: String {
        if dragging >= 0 { return passed ? "はなすと すすむ！" : "そのまま上へ ↑" }
        return hint ? "押したまま、上にスワイプ！ ↑" : "こたえを押したまま、上へ ↑"
    }

    private func option(_ q: LessonQ, _ i: Int) -> some View {
        let on = dragging == i
        return VStack(spacing: 6) {
            Text(q.options[i].0).font(.system(size: 34))
            Text(q.options[i].1).font(.dp(15, .heavy))
        }
        .foregroundColor(on ? Color(hex: 0x111111) : .white)
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.black.opacity(on ? 0.15 : 0.35)).offset(y: on ? 2 : 5)
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(on ? Color.white : Color.black.opacity(0.28))
                RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
            }
        )
        .scaleEffect(on ? 1.05 : 1)
        .offset(y: on ? -min(dy, 140) : 0)
        .opacity(dragging >= 0 && !on ? 0.4 : 1)
        .shadow(color: .black.opacity(on ? 0.35 : 0), radius: 16, y: 10)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if dragging != i {
                        dragging = i
                        passed = false
                        Haptic.light()
                    }
                    dy = max(0, -v.translation.height)
                    if dy > 60 && !passed { passed = true; Haptic.select() }
                    if dy <= 60 && passed { passed = false }
                }
                .onEnded { _ in
                    if passed {
                        choose(q, i)
                    } else {
                        hint = true
                        Haptic.soft(0.5)
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        dragging = -1
                        dy = 0
                        passed = false
                    }
                }
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: on)
    }

    private func choose(_ q: LessonQ, _ i: Int) {
        let ok = i == q.answer
        if ok { correct += 1; Haptic.success() } else { Haptic.soft(0.8) }
        withAnimation(.spring()) { toast = (ok, q.why) }
        let now = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if index == now + 1 || index == now { withAnimation { toast = nil } }
        }
        hint = false
        index += 1
    }

    private var endScreen: some View {
        ZStack {
            TopGlow(color: course.color, reach: 0.6)
            Confetti().ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Text(course.title).font(.dp(12, .heavy)).foregroundColor(.white.opacity(0.8)).padding(.top, 40)
                Text("おしまい！").font(.dp(34, .black))
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(correct)/\(course.questions.count)").font(.num(72)).foregroundColor(DP.yellow)
                        Text("ここで止められるの、えらい！").font(.dp(14, .bold))
                    }
                    Spacer()
                    DogView(size: 120, mood: .happy).bob(8, period: 1)
                }
                Text("GET! ⭐ +20")
                    .font(.num(16)).foregroundColor(.black)
                    .padding(.horizontal, 14).frame(height: 36)
                    .background(Capsule().fill(DP.yellow))
                Spacer()
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { game.flow = .pick }
                } label: {
                    Label("スマホを置く", systemImage: "play.fill")
                }
                .buttonStyle(PuffyStyle(color: .blue, height: 60))
                Button("もどる") { dismiss() }
                    .buttonStyle(PuffyStyle(color: .white, height: 54, strong: false))
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 16)
        }
        .onAppear {
            if !rewarded { rewarded = true; game.stars += 20; game.log("lesson:" + course.title) }
        }
    }
}

/// 折り返すチップ（iOS 16 でも動くように、行を自分で分ける）
private struct WrapChips: View {
    let items: [String]
    let selected: String?
    let tap: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) { ForEach(0..<2, id: \.self) { chip($0) } }
            HStack(spacing: 8) { ForEach(2..<4, id: \.self) { chip($0) } }
            HStack(spacing: 8) { ForEach(4..<items.count, id: \.self) { chip($0) } }
        }
    }

    private func chip(_ i: Int) -> some View {
        Button { tap(i) } label: { Chip(label: items[i], on: items[i] == selected).fixedSize() }
            .buttonStyle(PressStyle())
    }
}
