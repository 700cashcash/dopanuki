import SwiftUI

enum DogMood { case normal, happy, sleep }

/// 部屋でのうごき（なめらかにアニメーションできる値）
struct DogPose: Equatable {
    var earAngle: Double = 0     // 耳のぱたぱた（度）。＋で外へひらく
    var earsUp: Bool = false     // きいてるときの耳
    var tailWag: Double = 0      // しっぽ（度）
    var headTilt: Double = 0     // 首かしげ（度）
    var mouthOpen: CGFloat = 0   // 0〜1
    var eyes: DogMood? = nil     // 目だけ ちがう表情にする
    var teary = false            // 目うるうる（おかえりの直前）
    var squash: CGFloat = 0      // むぎゅっ（0〜1）
    var paw = false              // 「ありがと」の手
}

/// ドパ抜きちゃん（キャンバスのイラストをそのままSwiftUIで描いたもの）
struct DogView: View {
    var size: CGFloat = 120
    var mood: DogMood = .normal
    var scarf: Color = DP.blue
    var blinks = true
    var pose = DogPose()
    /// 夜ふかしした朝の見た目（0 = ツヤツヤ 〜 4 = 四角くなりかけ）
    var kimo = 0
    /// おなかの星がちらちら・たまに読み込み中くるくる／目がバグる
    var alive = false

    var body: some View {
        let m = pose.eyes ?? mood
        Group {
            if (m == .normal && blinks) || alive || kimo >= 3 {
                TimelineView(.animation(minimumInterval: 0.08, paused: false)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let blink = m == .normal && blinks && t.truncatingRemainder(dividingBy: 4.2) < 0.14
                    DogDrawing(mood: blink ? .sleep : m, scarf: scarf, pose: pose, kimo: kimo, t: t, alive: alive)
                }
            } else {
                DogDrawing(mood: m, scarf: scarf, pose: pose, kimo: kimo)
            }
        }
        .frame(width: 120, height: 120)
        .scaleEffect(size / 120)
        .frame(width: size, height: size)
        .accessibilityLabel(Text("ドパ抜きちゃん"))
    }
}

private struct DogDrawing: View {
    let mood: DogMood
    let scarf: Color
    var pose = DogPose()
    var kimo = 0
    var t: Double? = nil
    var alive = false

    /// まれに目がバグる（23秒に1回、0.18秒）
    private var glitching: Bool { alive && (t ?? 0).truncatingRemainder(dividingBy: 23) < 0.18 }
    /// まれに体に「読み込み中」くるくる（37秒に1回、1.4秒）
    private var loading: Bool { alive && ((t ?? 0) + 11).truncatingRemainder(dividingBy: 37) < 1.4 }
    private let fur = Color(hex: 0xF2D3A8)
    private let ear = Color(hex: 0xC98B5B)
    private let cream = Color(hex: 0xFFF5E6)
    private let ink = Color(hex: 0x2B1E16)

    var body: some View {
        ZStack {
            figure
                .scaleEffect(x: 1 + 0.16 * pose.squash, y: 1 - 0.2 * pose.squash, anchor: .bottom)
            if loading { spinner(cx: 60, cy: 100, r: 5, color: .white) }
        }
        .saturation(kimo >= 3 ? 0.3 : 1)
        .frame(width: 120, height: 120)
    }

    private var figure: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 84, y: 98))
                p.addQuadCurve(to: CGPoint(x: 97, y: 76), control: CGPoint(x: 100, y: 92))
            }
            .stroke(Color(hex: 0xE8C496), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            .frame(width: 120, height: 120)
            .rotationEffect(.degrees(pose.tailWag), anchor: UnitPoint(x: 84.0 / 120, y: 98.0 / 120))
            oval(60, 98, 27, 18, fur)
            oval(49, 112, 8, 5, cream)
            oval(71, 112, 8, 5, cream)
            Path { p in
                p.move(to: CGPoint(x: 40, y: 80))
                p.addLine(to: CGPoint(x: 80, y: 80))
                p.addQuadCurve(to: CGPoint(x: 60, y: 98), control: CGPoint(x: 74, y: 94))
                p.addQuadCurve(to: CGPoint(x: 40, y: 80), control: CGPoint(x: 46, y: 94))
                p.closeSubpath()
            }
            .fill(scarf)
            bellyWindow
            if pose.paw {
                oval(78, 86, 6.5, 5, fur, rot: -30)
                oval(81, 83, 4, 3, cream, rot: -30)
            }
            head
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(pose.headTilt), anchor: UnitPoint(x: 0.5, y: 80.0 / 120))
        }
        .frame(width: 120, height: 120)
    }

    private var head: some View {
        let earRot = (pose.earsUp ? -18 : 0) + pose.earAngle
        return ZStack {
            oval(29, pose.earsUp ? 44 : 50, 12, 21, ear, rot: 25 + earRot)
            oval(91, pose.earsUp ? 44 : 50, 12, 21, ear, rot: -25 - earRot)
            if kimo >= 2 {
                // ねぐせ（ぼさぼさ）
                Path { p in
                    for x in [CGFloat(48), 58, 68] {
                        p.move(to: CGPoint(x: x - 5, y: 26))
                        p.addLine(to: CGPoint(x: x, y: 13))
                        p.addLine(to: CGPoint(x: x + 5, y: 26))
                    }
                }
                .fill(fur)
            }
            if kimo >= 4 {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fur)
                    .frame(width: 66, height: 70).position(x: 60, y: 50)
            } else {
                oval(60, 52, 34, 31, fur)
            }
            oval(60, 65, 16, 11, cream)
            oval(40, 63, 5.5, 3.2, Color(hex: 0xFF9AA2).opacity(0.6))
            oval(80, 63, 5.5, 3.2, Color(hex: 0xFF9AA2).opacity(0.6))
            if kimo >= 1 {
                // クマ
                oval(46, 59, 6, 2.2, Color(hex: 0x6B4E8C).opacity(kimo >= 2 ? 0.55 : 0.25))
                oval(74, 59, 6, 2.2, Color(hex: 0x6B4E8C).opacity(kimo >= 2 ? 0.55 : 0.25))
            }
            eyes
                .offset(x: glitching ? 2.5 : 0)
            if glitching {
                eyes.offset(x: -3).opacity(0.6).colorMultiply(Color(hex: 0x00E5FF))
            }
            oval(60, 60, 4.6, 3.3, ink)
            Path { p in
                p.move(to: CGPoint(x: 60, y: 63))
                p.addLine(to: CGPoint(x: 60, y: 66))
                p.addQuadCurve(to: CGPoint(x: 53, y: 66.5), control: CGPoint(x: 56.5, y: 70))
                p.move(to: CGPoint(x: 60, y: 66))
                p.addQuadCurve(to: CGPoint(x: 67, y: 66.5), control: CGPoint(x: 63.5, y: 70))
            }
            .stroke(ink, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            if pose.mouthOpen > 0.02 {
                oval(60, 69 + 3 * pose.mouthOpen, 4.5, 1 + 5 * pose.mouthOpen, Color(hex: 0x8C2F3A))
                oval(60, 71 + 4.5 * pose.mouthOpen, 2.8, 1.2 * pose.mouthOpen + 0.3, Color(hex: 0xFF7E8C))
            }
        }
    }

    /// おなかの小さな窓（中で星がちらちら）
    private var bellyWindow: some View {
        let tt = t ?? 0
        return ZStack {
            oval(60, 102, 7.5, 6, Color(hex: 0x1B1F5C))
            ForEach(0..<3, id: \.self) { i in
                let tw = 0.45 + 0.55 * abs(sin(tt * (1.3 + Double(i) * 0.7) + Double(i)))
                oval([56.5, 61.5, 59][i], [100.5, 101.5, 104.5][i], [0.9, 1.2, 0.7][i], [0.9, 1.2, 0.7][i],
                     Color(hex: [0xFFF6B0, 0xFFFFFF, 0xBFE3FF][i]).opacity(t == nil ? 0.9 : tw))
            }
        }
    }

    /// 読み込み中のくるくる
    private func spinner(cx: CGFloat, cy: CGFloat, r: CGFloat, color: Color) -> some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(color, style: StrokeStyle(lineWidth: max(1.2, r * 0.35), lineCap: .round))
            .frame(width: r * 2, height: r * 2)
            .rotationEffect(.degrees((t ?? 0) * 400))
            .position(x: cx, y: cy)
    }

    @ViewBuilder private var eyes: some View {
        if kimo >= 3 && mood != .sleep {
            ZStack {
                oval(46, 52, 5.2, 5.2, Color(hex: 0x3A3A3A))
                oval(74, 52, 5.2, 5.2, Color(hex: 0x3A3A3A))
                spinner(cx: 46, cy: 52, r: 3.2, color: .white)
                spinner(cx: 74, cy: 52, r: 3.2, color: .white)
            }
        } else {
            plainEyes
        }
    }

    @ViewBuilder private var plainEyes: some View {
        switch mood {
        case .normal:
            ZStack {
                if kimo == 2 {
                    oval(46, 52, 6.4, 6.4, Color(hex: 0xFFB3B3))
                    oval(74, 52, 6.4, 6.4, Color(hex: 0xFFB3B3))
                }
                oval(46, 52, pose.teary ? 6.2 : 5.2, pose.teary ? 6.2 : 5.2, ink)
                oval(74, 52, pose.teary ? 6.2 : 5.2, pose.teary ? 6.2 : 5.2, ink)
                oval(47.9, 50.1, pose.teary ? 2.3 : 1.7, pose.teary ? 2.3 : 1.7, .white)
                oval(75.9, 50.1, pose.teary ? 2.3 : 1.7, pose.teary ? 2.3 : 1.7, .white)
                if pose.teary {
                    oval(44.5, 54.5, 1, 1, .white)
                    oval(72.5, 54.5, 1, 1, .white)
                    oval(46, 57.5, 5, 1.2, Color(hex: 0x8FD3FF).opacity(0.85))
                    oval(74, 57.5, 5, 1.2, Color(hex: 0x8FD3FF).opacity(0.85))
                }
            }
        case .happy:
            Path { p in
                for cx in [CGFloat(46), CGFloat(74)] {
                    p.move(to: CGPoint(x: cx - 5, y: 54))
                    p.addQuadCurve(to: CGPoint(x: cx + 5, y: 54), control: CGPoint(x: cx, y: 46))
                }
            }
            .stroke(ink, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        case .sleep:
            Path { p in
                for cx in [CGFloat(46), CGFloat(74)] {
                    p.move(to: CGPoint(x: cx - 5, y: 51))
                    p.addQuadCurve(to: CGPoint(x: cx + 5, y: 51), control: CGPoint(x: cx, y: 56))
                }
            }
            .stroke(ink, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }
    }

    private func oval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ c: Color, rot: Double = 0) -> some View {
        Ellipse()
            .fill(c)
            .frame(width: rx * 2, height: ry * 2)
            .rotationEffect(.degrees(rot))
            .position(x: cx, y: cy)
    }
}
