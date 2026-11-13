import SwiftUI
import UIKit

// MARK: - 色（黒×ぷっくり。かわいいのはドパ抜きちゃんだけ）

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

enum DP {
    static let bg = Color(hex: 0x0A0A0A)
    static let card = Color(hex: 0x161616)
    static let card2 = Color(hex: 0x232323)
    static let line = Color(hex: 0x262626)
    static let gray = Color(hex: 0xA7A7A7)
    static let dim = Color(hex: 0x6A6A6A)
    static let blue = Color(hex: 0x4C8DF0)
    static let pink = Color(hex: 0xFF5DA2)
    static let yellow = Color(hex: 0xFFC531)
    static let green = Color(hex: 0x7CF29A)
    static let purple = Color(hex: 0x5B4BE0)
    static let violet = Color(hex: 0x7C6CF0)
    static let orange = Color(hex: 0xFF8A3D)
    static let red = Color(hex: 0xFF4D5E)
    static let navy = Color(hex: 0x1B2A55)
}

extension Font {
    /// 数字は極太
    static func num(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy).monospacedDigit() }
    static func dp(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font { .system(size: size, weight: weight) }
}

// MARK: - 振動

enum Haptic {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func soft(_ intensity: CGFloat = 1) { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: intensity) }
    static func rigid() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

// MARK: - ぷっくりボタン（押すと沈んで、ばねで戻る＋振動）

enum PuffColor {
    case blue, white, black, yellow, green, purple

    var top: Color {
        switch self {
        case .blue: return Color(hex: 0x8FB8FF)
        case .white: return .white
        case .black: return Color(hex: 0x4A4A4A)
        case .yellow: return Color(hex: 0xFFE28A)
        case .green: return Color(hex: 0xA6F5C0)
        case .purple: return Color(hex: 0xC9BFFF)
        }
    }
    var mid: Color {
        switch self {
        case .blue: return Color(hex: 0x4C8DF0)
        case .white: return Color(hex: 0xF1F1F1)
        case .black: return Color(hex: 0x222222)
        case .yellow: return Color(hex: 0xFFC531)
        case .green: return Color(hex: 0x5CD38A)
        case .purple: return Color(hex: 0x7C6CF0)
        }
    }
    var bottom: Color {
        switch self {
        case .blue: return Color(hex: 0x2D63C8)
        case .white: return Color(hex: 0xCFCFCF)
        case .black: return Color(hex: 0x111111)
        case .yellow: return Color(hex: 0xE59A00)
        case .green: return Color(hex: 0x2E9E5E)
        case .purple: return Color(hex: 0x4B3BC0)
        }
    }
    var edge: Color {
        switch self {
        case .blue: return Color(hex: 0x1F4A9A)
        case .white: return Color(hex: 0x9A9A9A)
        case .black: return .black
        case .yellow: return Color(hex: 0xB57500)
        case .green: return Color(hex: 0x1F7A45)
        case .purple: return Color(hex: 0x352A8F)
        }
    }
    var text: Color {
        switch self {
        case .white: return Color(hex: 0x111111)
        case .yellow: return Color(hex: 0x2A1C00)
        case .green: return Color(hex: 0x062A14)
        default: return .white
        }
    }
    var glow: Color {
        switch self {
        case .white, .black: return .black
        default: return mid
        }
    }
}

struct PuffyStyle: ButtonStyle {
    var color: PuffColor = .blue
    var height: CGFloat = 58
    var circle = false
    var fullWidth = true
    var strong = true

    func makeBody(configuration: Configuration) -> some View {
        PuffyBody(configuration: configuration, color: color, height: height,
                  circle: circle, fullWidth: fullWidth, strong: strong)
    }
}

private struct PuffyBody: View {
    let configuration: ButtonStyle.Configuration
    let color: PuffColor
    let height: CGFloat
    let circle: Bool
    let fullWidth: Bool
    let strong: Bool

    var body: some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: height / 2, style: .continuous)
        configuration.label
            .font(.dp(17, .heavy))
            .foregroundColor(color.text)
            .padding(.horizontal, circle ? 0 : 26)
            .frame(maxWidth: (fullWidth && !circle) ? .infinity : nil)
            .frame(width: circle ? height : nil, height: height)
            .background(
                ZStack {
                    shape.fill(color.edge).offset(y: pressed ? 1 : 6)
                    shape.fill(RadialGradient(colors: [color.top, color.mid, color.bottom],
                                              center: .top, startRadius: 0, endRadius: height * 1.6))
                    shape.fill(LinearGradient(colors: [Color.white.opacity(0.38), Color.white.opacity(0)],
                                              startPoint: .top, endPoint: .bottom))
                        .padding(.horizontal, circle ? height * 0.18 : height * 0.3)
                        .padding(.top, 4)
                        .padding(.bottom, height * 0.55)
                    shape.strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                }
            )
            .shadow(color: color.glow.opacity(0.55), radius: 14, x: 0, y: 10)
            .offset(y: pressed ? 5 : 0)
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(pressed ? .easeOut(duration: 0.07) : .spring(response: 0.32, dampingFraction: 0.45), value: pressed)
            .onChange(of: pressed) { p in
                if p { strong ? Haptic.medium() : Haptic.light() }
            }
    }
}

/// カード・チップ用：押すと0.94にへこんで戻る
struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    func makeBody(configuration: Configuration) -> some View {
        PressBody(configuration: configuration, scale: scale)
    }
}

private struct PressBody: View {
    let configuration: ButtonStyle.Configuration
    let scale: CGFloat
    var body: some View {
        let pressed = configuration.isPressed
        configuration.label
            .scaleEffect(pressed ? scale : 1)
            .brightness(pressed ? -0.08 : 0)
            .animation(pressed ? .easeOut(duration: 0.07) : .spring(response: 0.32, dampingFraction: 0.45), value: pressed)
            .onChange(of: pressed) { p in if p { Haptic.light() } }
    }
}

// MARK: - 部品

/// 上だけうすく色がつく背景
struct TopGlow: View {
    var color: Color
    var reach: CGFloat = 0.45
    var body: some View {
        LinearGradient(colors: [color, DP.bg], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: reach))
            .background(DP.bg)
            .ignoresSafeArea()
    }
}

struct Chip: View {
    var label: String
    var on: Bool
    var body: some View {
        Text(label)
            .font(.dp(13, .bold))
            .foregroundColor(on ? .black : .white)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Capsule().fill(on ? Color.white : DP.card2))
    }
}

struct CircleIcon: View {
    var system: String
    var size: CGFloat = 40
    var body: some View {
        Image(systemName: system)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(DP.card2))
    }
}

/// うねうね動く色のかたまり
struct BlobShape: Shape {
    var phase: CGFloat
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let R = min(rect.width, rect.height) / 2
        var p = Path()
        let n = 72
        for i in 0...n {
            let a = CGFloat(i) / CGFloat(n) * 2 * .pi
            let r = R * (0.86 + 0.09 * sin(3 * a + phase) + 0.05 * sin(2 * a - 2 * phase))
            let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

struct Blob: View {
    var color: Color
    var size: CGFloat
    var period: Double = 9
    var offset: Double = 0
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate / period + offset
            let ph = CGFloat(t.truncatingRemainder(dividingBy: 1) * 2 * .pi)
            BlobShape(phase: ph)
                .fill(color)
                .rotationEffect(.radians(Double(ph)))
                .frame(width: size, height: size)
        }
        .allowsHitTesting(false)
    }
}

/// ゆらゆら上下（ふわふわ）
struct Bob: ViewModifier {
    var amount: CGFloat = 5
    var period: Double = 2.4
    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            content.offset(y: CGFloat(sin(t / period * 2 * .pi)) * amount)
        }
    }
}

extension View {
    func bob(_ amount: CGFloat = 5, period: Double = 2.4) -> some View { modifier(Bob(amount: amount, period: period)) }
}

/// 数字のカウントアップ
struct CountUp: View, Animatable {
    var value: Double
    var font: Font
    var color: Color = .white
    var grouped = true
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }
    var body: some View {
        Text(grouped ? Int(value).formatted() : "\(Int(value))")
            .font(font)
            .foregroundColor(color)
    }
}

/// 紙ふぶき
struct Confetti: View {
    private struct Piece {
        let x: CGFloat, speed: CGFloat, delay: Double, spin: Double, color: Color, w: CGFloat
    }
    private let pieces: [Piece] = (0..<36).map { i in
        let colors = [DP.pink, DP.yellow, DP.green, DP.blue, Color.white, DP.violet]
        return Piece(x: CGFloat.random(in: 0...1),
                     speed: CGFloat.random(in: 160...320),
                     delay: Double.random(in: 0...2.5),
                     spin: Double.random(in: 90...420),
                     color: colors[i % colors.count],
                     w: CGFloat.random(in: 7...11))
    }
    @State private var start = Date()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSince(start)
                ZStack {
                    ForEach(0..<pieces.count, id: \.self) { i in
                        let p = pieces[i]
                        let life = max(0, t - p.delay)
                        let y = (CGFloat(life) * p.speed).truncatingRemainder(dividingBy: geo.size.height + 60) - 30
                        RoundedRectangle(cornerRadius: 2)
                            .fill(p.color)
                            .frame(width: p.w, height: p.w * 1.5)
                            .rotationEffect(.degrees(life * p.spin))
                            .position(x: p.x * geo.size.width + CGFloat(sin(life * 2 + Double(i))) * 14, y: y)
                            .opacity(life > 0 ? 1 : 0)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// 黒いふきだし
struct Bubble: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.dp(14, .bold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.black.opacity(0.72)))
    }
}
