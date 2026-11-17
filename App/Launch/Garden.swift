import SwiftUI

/// 実（12種：ノーマル6・レア4・SSレア2）
struct Fruit: Identifiable, Equatable {
    enum Shape { case berry, round, grape, peach, apple, banana, melon, star, cosmos, light }
    let id: String
    let name: String
    let rarity: Int            // 0 ノーマル, 1 レア, 2 SSレア
    let shape: Shape
    let colors: [Color]
    let review: String         // 食レポ1行

    var rarityLabel: String { ["ノーマル", "レア", "SSレア"][rarity] }

    static let all: [Fruit] = [
        Fruit(id: "ichigo", name: "いちご", rarity: 0, shape: .berry, colors: [Color(hex: 0xFF4D6A), Color(hex: 0xD62848)], review: "あまずっぱい！ ほっぺが きゅっ"),
        Fruit(id: "mikan", name: "みかん", rarity: 0, shape: .round, colors: [Color(hex: 0xFFB238), Color(hex: 0xF08A12)], review: "じゅわっ。おひさまの味"),
        Fruit(id: "budou", name: "ぶどう", rarity: 0, shape: .grape, colors: [Color(hex: 0x8E5BD9), Color(hex: 0x5B2FA8)], review: "ぷちっ、ぷちっ。とまらない"),
        Fruit(id: "momo", name: "もも", rarity: 0, shape: .peach, colors: [Color(hex: 0xFFC2C8), Color(hex: 0xFF8FA0)], review: "やわらか〜。とろける"),
        Fruit(id: "ringo", name: "りんご", rarity: 0, shape: .apple, colors: [Color(hex: 0xF0453B), Color(hex: 0xB82222)], review: "しゃくっ！ いい音"),
        Fruit(id: "banana", name: "バナナ", rarity: 0, shape: .banana, colors: [Color(hex: 0xFFE066), Color(hex: 0xF2C230)], review: "もっちり。元気でる"),
        Fruit(id: "melon", name: "きらきらメロン", rarity: 1, shape: .melon, colors: [Color(hex: 0xA8F0A0), Color(hex: 0x4FBF5A)], review: "あま〜い…きらきらが のどを通った"),
        Fruit(id: "hoshi", name: "ほしのみ", rarity: 1, shape: .star, colors: [Color(hex: 0xFFF3A0), Color(hex: 0xFFC531)], review: "しゅわっ。口の中で ほしが はじけた"),
        Fruit(id: "niji", name: "にじいちご", rarity: 1, shape: .berry, colors: [Color(hex: 0xFF6B9D), Color(hex: 0xFFD166), Color(hex: 0x6EE7B7), Color(hex: 0x7C9CFF)], review: "ひとくちごとに 味がかわる！"),
        Fruit(id: "yume", name: "ゆめぶどう", rarity: 1, shape: .grape, colors: [Color(hex: 0xC8B6FF), Color(hex: 0xFFB3DE)], review: "ふわふわ…ねむくなる味"),
        Fruit(id: "uchu", name: "うちゅうのみ", rarity: 2, shape: .cosmos, colors: [Color(hex: 0x1B1F5C), Color(hex: 0x6A4BC4)], review: "…おなかの宇宙が ひろがった"),
        Fruit(id: "hikari", name: "ひかりのたね", rarity: 2, shape: .light, colors: [Color(hex: 0xFFFFFF), Color(hex: 0xFFE08A)], review: "まぶしい…ぼく、ひかってない？"),
    ]

    static func find(_ id: String?) -> Fruit? { all.first { $0.id == id } }

    /// 置いた時間でレア度が決まる（長いほど確率アップ）。途中でやめたら小さいノーマル
    static func roll(minutes m: Int, completed: Bool) -> Fruit {
        let pool = { (r: Int) in all.filter { $0.rarity == r }.randomElement()! }
        guard completed else { return pool(0) }
        let ss = m >= 60 ? min(0.05 + Double(m - 60) / 600, 0.4) : 0
        let rare = m >= 25 ? min(0.15 + Double(m - 25) / 200, 0.55) : 0.02
        let x = Double.random(in: 0..<1)
        if x < ss { return pool(2) }
        if x < ss + rare { return pool(1) }
        return pool(0)
    }
}

/// 実の絵（SwiftUIの図形とグラデ）
struct FruitView: View {
    let fruit: Fruit
    var size: CGFloat = 60
    var silhouette = false

    var body: some View {
        ZStack { shape }
            .frame(width: 60, height: 60)
            .scaleEffect(size / 60)
            .frame(width: size, height: size)
            .colorMultiply(silhouette ? .black : .white)
            .opacity(silhouette ? 0.55 : 1)
    }

    private var grad: LinearGradient {
        LinearGradient(colors: fruit.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    @ViewBuilder private var shape: some View {
        switch fruit.shape {
        case .berry:
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 30, y: 54))
                    p.addCurve(to: CGPoint(x: 8, y: 20), control1: CGPoint(x: 16, y: 46), control2: CGPoint(x: 6, y: 32))
                    p.addCurve(to: CGPoint(x: 52, y: 20), control1: CGPoint(x: 14, y: 8), control2: CGPoint(x: 46, y: 8))
                    p.addCurve(to: CGPoint(x: 30, y: 54), control1: CGPoint(x: 54, y: 32), control2: CGPoint(x: 44, y: 46))
                }
                .fill(grad)
                ForEach(0..<7, id: \.self) { i in
                    Ellipse().fill(Color(hex: 0xFFF3B0)).frame(width: 2.5, height: 4)
                        .position(x: [20, 30, 40, 24, 36, 30, 18][i], y: [24, 22, 24, 33, 33, 43, 32][i])
                }
                leaf(y: 13)
            }
        case .round:
            ZStack { Circle().fill(grad).frame(width: 46, height: 46).position(x: 30, y: 33); leaf(y: 11) }
        case .grape:
            ZStack {
                ForEach(0..<9, id: \.self) { i in
                    Circle().fill(grad).frame(width: 15, height: 15)
                        .position(x: [20, 30, 40, 25, 35, 30, 20, 40, 30][i], y: [18, 16, 18, 27, 27, 36, 36, 36, 46][i])
                }
                Rectangle().fill(Color(hex: 0x6B4E2E)).frame(width: 2.5, height: 8).position(x: 30, y: 8)
            }
        case .peach:
            ZStack {
                Circle().fill(grad).frame(width: 46, height: 46).position(x: 30, y: 33)
                Path { p in p.move(to: CGPoint(x: 30, y: 12)); p.addQuadCurve(to: CGPoint(x: 27, y: 50), control: CGPoint(x: 22, y: 30)) }
                    .stroke(Color.white.opacity(0.4), lineWidth: 2)
                leaf(y: 11)
            }
        case .apple:
            ZStack {
                Ellipse().fill(grad).frame(width: 48, height: 44).position(x: 30, y: 34)
                Rectangle().fill(Color(hex: 0x6B4E2E)).frame(width: 2.5, height: 9).position(x: 30, y: 12)
                leaf(y: 12, x: 36)
            }
        case .banana:
            Path { p in
                p.move(to: CGPoint(x: 10, y: 18))
                p.addQuadCurve(to: CGPoint(x: 52, y: 22), control: CGPoint(x: 24, y: 64))
                p.addQuadCurve(to: CGPoint(x: 10, y: 18), control: CGPoint(x: 26, y: 46))
            }
            .fill(grad)
        case .melon:
            ZStack {
                Circle().fill(grad).frame(width: 48, height: 48).position(x: 30, y: 32)
                ForEach(0..<4, id: \.self) { i in
                    Circle().stroke(Color.white.opacity(0.35), lineWidth: 1).frame(width: 48, height: 48)
                        .scaleEffect(x: 0.3 + Double(i) * 0.22, y: 1).position(x: 30, y: 32)
                }
                sparkle(x: 44, y: 18)
            }
        case .star:
            ZStack {
                StarShape().fill(grad).frame(width: 52, height: 52).position(x: 30, y: 31)
                sparkle(x: 48, y: 12)
            }
        case .cosmos:
            ZStack {
                Circle().fill(RadialGradient(colors: fruit.colors.reversed(), center: .topLeading, startRadius: 2, endRadius: 40))
                    .frame(width: 48, height: 48).position(x: 30, y: 31)
                ForEach(0..<7, id: \.self) { i in
                    Circle().fill(Color.white).frame(width: [2, 1.5, 2.5, 1.5, 2, 1.5, 3][i], height: [2, 1.5, 2.5, 1.5, 2, 1.5, 3][i])
                        .position(x: [20, 36, 28, 42, 18, 33, 38][i], y: [22, 18, 34, 30, 40, 44, 24][i])
                }
                Circle().strokeBorder(Color(hex: 0xBFA8FF).opacity(0.7), lineWidth: 1.5).frame(width: 62, height: 18)
                    .rotationEffect(.degrees(-20)).position(x: 30, y: 32)
            }
        case .light:
            ZStack {
                Circle().fill(Color(hex: 0xFFE08A).opacity(0.5)).frame(width: 56, height: 56).blur(radius: 8).position(x: 30, y: 32)
                Ellipse().fill(grad).frame(width: 30, height: 40).position(x: 30, y: 32)
                sparkle(x: 46, y: 14); sparkle(x: 14, y: 46)
            }
        }
    }

    private func leaf(y: CGFloat, x: CGFloat = 30) -> some View {
        Ellipse().fill(Color(hex: 0x4FBF5A)).frame(width: 16, height: 7).rotationEffect(.degrees(-20)).position(x: x + 4, y: y)
    }

    private func sparkle(x: CGFloat, y: CGFloat) -> some View {
        StarShape(points: 4, inner: 0.3).fill(Color.white).frame(width: 10, height: 10).position(x: x, y: y)
    }
}

struct StarShape: Shape {
    var points = 5
    var inner: CGFloat = 0.45
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY), R = min(r.width, r.height) / 2
        for i in 0..<(points * 2) {
            let a = Double(i) * .pi / Double(points) - .pi / 2
            let rad = i % 2 == 0 ? R : R * inner
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rad, y: c.y + CGFloat(sin(a)) * rad)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }
}

/// はたけ（セッション中に、ちょっとずつ育つ芽）
struct SproutView: View {
    var growth: Double        // 0〜1
    @State private var planted = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse().fill(Color(hex: 0x6B4A2E)).frame(width: 70, height: 20)
            Ellipse().fill(Color(hex: 0x8A6240)).frame(width: 54, height: 12).offset(y: -3)
            ZStack(alignment: .bottom) {
                Capsule().fill(Color(hex: 0x4FBF5A)).frame(width: 3, height: 6 + 26 * growth)
                Ellipse().fill(Color(hex: 0x6EE07A)).frame(width: 12 + 6 * growth, height: 7)
                    .rotationEffect(.degrees(-30)).offset(x: -6, y: -(4 + 20 * growth))
                Ellipse().fill(Color(hex: 0x6EE07A)).frame(width: 12 + 6 * growth, height: 7)
                    .rotationEffect(.degrees(30)).offset(x: 6, y: -(6 + 22 * growth))
            }
            .offset(y: -8)
            .scaleEffect(planted ? 1 : 0.1, anchor: .bottom)
            // ぽんっ（植えたしるし）
            Circle().fill(Color(hex: 0x8A6240)).frame(width: 8, height: 8)
                .offset(y: planted ? -6 : -60)
                .opacity(planted ? 0 : 1)
        }
        .frame(width: 80, height: 60)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.3)) { planted = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { Haptic.light() }
        }
        .accessibilityLabel(Text("はたけ：たねが育ってる"))
    }
}

// MARK: - 収穫：実を指でなぞって ポンッ → ドパ抜きちゃんが ぱくっ

struct HarvestView: View {
    let fruit: Fruit
    let small: Bool
    var onDone: () -> Void

    @State private var drag: CGFloat = 0
    @State private var picked = false
    @State private var eaten = false
    @State private var dogPose = DogPose(teary: true)
    @State private var jump: CGFloat = 0
    @State private var glow = false
    @State private var fly: CGSize = .zero
    @State private var line = ""

    var body: some View {
        VStack(spacing: 18) {
            Text(picked ? (eaten ? "\(fruit.rarityLabel)！ \(fruit.name)" : "ポンッ！") : "なぞって とってね").font(.dp(24, .heavy))
                .padding(.top, 30)
                .animation(.easeOut, value: picked)
            Spacer()
            ZStack {
                // レア以上は、とる前に光で予告（金・虹）
                if fruit.rarity > 0 && !eaten {
                    Circle()
                        .fill(fruit.rarity == 2
                              ? AnyShapeStyle(AngularGradient(colors: [DP.pink, DP.yellow, DP.green, DP.blue, DP.violet, DP.pink], center: .center))
                              : AnyShapeStyle(DP.yellow))
                        .frame(width: 170, height: 170).blur(radius: 30)
                        .opacity(glow ? 0.85 : 0.35)
                        .offset(y: -150)
                }
                // くき
                if !picked {
                    Capsule().fill(Color(hex: 0x4FBF5A)).frame(width: 4, height: 60).offset(y: -95)
                }
                // 実
                if !eaten {
                    FruitView(fruit: fruit, size: small ? 70 : 100)
                        .offset(x: fly.width, y: -150 + min(0, drag) + fly.height)
                        .scaleEffect(picked ? 1.15 : 1 + abs(min(0, drag)) / 600, anchor: .bottom)
                        .rotationEffect(.degrees(Double(drag) / 8))
                        .gesture(pickGesture)
                        .accessibilityLabel(Text(fruit.name + "。上になぞって とる"))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { pick() }
                }
                DogView(size: 190, mood: eaten ? .happy : .normal, blinks: !picked, pose: dogPose, alive: true)
                    .offset(y: 60 - jump)
                if eaten {
                    VStack(spacing: 6) {
                        Bubble(text: "んま！ " + line)
                        if small { Text("ちいさいけど、おいしいよ").font(.dp(12, .bold)).foregroundColor(DP.gray) }
                    }
                    .offset(y: -150)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .frame(height: 420)
            Spacer()
            if eaten {
                Button { onDone() } label: { Text("つぎへ") }
                    .buttonStyle(PuffyStyle(color: .white, height: 52, strong: false))
                    .padding(.horizontal, 24).padding(.bottom, 20)
            } else {
                Image(systemName: "hand.point.up.left.fill").font(.system(size: 26)).foregroundColor(.white.opacity(0.6))
                    .offset(y: picked ? 0 : -8)
                    .animation(.easeInOut(duration: 0.8).repeatForever(), value: picked)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            if fruit.rarity > 0 {
                withAnimation(.easeInOut(duration: 0.7).repeatForever()) { glow = true }
                Haptic.soft()
            }
        }
    }

    private var pickGesture: some Gesture {
        DragGesture()
            .onChanged { v in
                guard !picked else { return }
                drag = v.translation.height
                if Int(abs(drag)) % 20 == 0 { Haptic.soft(0.4) }
            }
            .onEnded { v in
                if v.translation.height < -50 || abs(v.translation.width) > 60 { pick() }
                else { withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { drag = 0 } }
            }
    }

    /// ポンッ → ぱくっ → ごほうび顔
    private func pick() {
        guard !picked else { return }
        Haptic.success()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { picked = true; drag = -40 }
        // わくわく（実が ドパ抜きちゃんの口へ）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeIn(duration: 0.35)) { fly = CGSize(width: 0, height: 170); dogPose = DogPose(mouthOpen: 1, teary: true) }
        }
        // ぱくっ
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            Haptic.medium()
            withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) {
                eaten = true
                dogPose = DogPose(squash: 0.8)
                jump = 10
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { dogPose = DogPose(tailWag: 18, mouthOpen: 0.4, paw: true); jump = 0 }
                line = fruit.review
                Haptic.success()
            }
        }
    }
}

// MARK: - 図鑑（記録タブの中）

struct DexSection: View {
    @EnvironmentObject var life: LifeState
    @State private var opened: Fruit?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("図鑑").font(.dp(16, .heavy))
                Spacer()
                Text("\(Fruit.all.filter { life.data.eaten[$0.id] != nil }.count) / \(Fruit.all.count)")
                    .font(.num(13)).foregroundColor(DP.gray)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Fruit.all) { f in
                    let n = life.data.eaten[f.id]
                    Button { if n != nil { opened = f } } label: {
                        VStack(spacing: 4) {
                            FruitView(fruit: f, size: 46, silhouette: n == nil)
                            Text(n == nil ? "？？？" : f.name).font(.dp(10, .heavy)).lineLimit(1).minimumScaleFactor(0.7)
                                .foregroundColor(n == nil ? DP.dim : .white)
                        }
                        .frame(maxWidth: .infinity).frame(height: 82)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(f.rarity == 2 && n != nil ? Color(hex: 0x2A2450) : (f.rarity == 1 && n != nil ? Color(hex: 0x3A3216) : DP.card)))
                    }
                    .buttonStyle(PressStyle())
                }
            }
        }
        .alert(opened?.name ?? "", isPresented: Binding(get: { opened != nil }, set: { if !$0 { opened = nil } })) {
            Button("OK") { opened = nil }
        } message: {
            if let f = opened { Text("\(f.rarityLabel) ・ \(life.data.eaten[f.id] ?? 0)こ 食べた\n「\(f.review)」") }
        }
    }
}
