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
}

/// ドパ抜きちゃん（キャンバスのイラストをそのままSwiftUIで描いたもの）
struct DogView: View {
    var size: CGFloat = 120
    var mood: DogMood = .normal
    var scarf: Color = DP.blue
    var blinks = true
    var pose = DogPose()

    var body: some View {
        let m = pose.eyes ?? mood
        Group {
            if m == .normal && blinks {
                TimelineView(.animation(minimumInterval: 0.08, paused: false)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4.2)
                    DogDrawing(mood: t < 0.14 ? .sleep : .normal, scarf: scarf, pose: pose)
                }
            } else {
                DogDrawing(mood: m, scarf: scarf, pose: pose)
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
    private let fur = Color(hex: 0xF2D3A8)
    private let ear = Color(hex: 0xC98B5B)
    private let cream = Color(hex: 0xFFF5E6)
    private let ink = Color(hex: 0x2B1E16)

    var body: some View {
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
            oval(60, 52, 34, 31, fur)
            oval(60, 65, 16, 11, cream)
            oval(40, 63, 5.5, 3.2, Color(hex: 0xFF9AA2).opacity(0.6))
            oval(80, 63, 5.5, 3.2, Color(hex: 0xFF9AA2).opacity(0.6))
            eyes
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

    @ViewBuilder private var eyes: some View {
        switch mood {
        case .normal:
            ZStack {
                oval(46, 52, 5.2, 5.2, ink)
                oval(74, 52, 5.2, 5.2, ink)
                oval(47.9, 50.1, 1.7, 1.7, .white)
                oval(75.9, 50.1, 1.7, 1.7, .white)
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
