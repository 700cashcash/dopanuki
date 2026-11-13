import SwiftUI
import UIKit

/// 深呼吸の背景になる「景色」。ガチャで集められる
struct NatureScene: Identifiable, Equatable {
    let id: String
    let name: String
    let photo: String?        // バンドル内の写真ファイル名（なければグラデーション）
    let colors: [Color]
    let rarity: String

    /// 持っていなくても最初から見られる
    var isDefault: Bool { rarity == "はじめから" }

    var image: UIImage? {
        guard let p = photo else { return nil }
        if let img = UIImage(named: p) { return img }
        let parts = p.split(separator: ".")
        guard parts.count == 2,
              let path = Bundle.main.path(forResource: String(parts[0]), ofType: String(parts[1])) else { return nil }
        return UIImage(contentsOfFile: path)
    }
}

enum Scenes {
    static let all: [NatureScene] = [
        NatureScene(id: "forest", name: "森", photo: "photo1.jpg",
                    colors: [Color(hex: 0x0F3D2E), Color(hex: 0x2E7D4F), Color(hex: 0x9BD08A)], rarity: "はじめから"),
        NatureScene(id: "lake", name: "湖", photo: "photo2.jpg",
                    colors: [Color(hex: 0x10324F), Color(hex: 0x2F7BA8), Color(hex: 0xBFE6F2)], rarity: "はじめから"),
        NatureScene(id: "meadow", name: "草原", photo: "photo3.jpg",
                    colors: [Color(hex: 0x3D6B2A), Color(hex: 0x8DBF5A), Color(hex: 0xF4E9A8)], rarity: "はじめから"),
        NatureScene(id: "mountain", name: "山", photo: "mountain.jpg",
                    colors: [Color(hex: 0x23305E), Color(hex: 0x5B6FB0), Color(hex: 0xE7C6D6)], rarity: "はじめから"),
        NatureScene(id: "sea", name: "海", photo: nil,
                    colors: [Color(hex: 0x053A5C), Color(hex: 0x1386B5), Color(hex: 0x8EE3EF)], rarity: "道"),
        NatureScene(id: "sunset", name: "夕焼け", photo: nil,
                    colors: [Color(hex: 0x3A1C5C), Color(hex: 0xE0457B), Color(hex: 0xFFB45C)], rarity: "道"),
        NatureScene(id: "snow", name: "雪山", photo: nil,
                    colors: [Color(hex: 0x2B4466), Color(hex: 0x9EB8D6), Color(hex: 0xF4F8FC)], rarity: "道"),
        NatureScene(id: "stars", name: "星空", photo: nil,
                    colors: [Color(hex: 0x05061A), Color(hex: 0x1B1F5C), Color(hex: 0x6A4BC4)], rarity: "道"),
        NatureScene(id: "sakura", name: "桜", photo: nil,
                    colors: [Color(hex: 0x6E3B5A), Color(hex: 0xF29CC0), Color(hex: 0xFFE6EF)], rarity: "道"),
        NatureScene(id: "fall", name: "滝", photo: nil,
                    colors: [Color(hex: 0x123B33), Color(hex: 0x3E8F80), Color(hex: 0xD6F2EC)], rarity: "道"),
    ]

    /// はじめからの4つ ＋ ごほうびの道で ひらいた景色
    static func owned(breathMinutes: Int) -> [NatureScene] {
        let opened = Set(Road.all.filter { $0.kind == .scene && $0.minutes <= breathMinutes }.map { $0.id })
        return all.filter { $0.isDefault || opened.contains($0.id) }
    }
}

/// ごほうびの道（深呼吸10分ごとに、景色と音がかわりばんこにひらく）
struct RoadReward: Identifiable, Equatable {
    enum Kind { case scene, sound }
    let minutes: Int
    let kind: Kind
    let id: String
    let name: String
    var icon: String { kind == .scene ? "photo.fill" : "music.note" }
    var getText: String { kind == .scene ? "\(name)の景色をGET！" : "「\(name)」をGET！" }
}

enum Road {
    static let all: [RoadReward] = [
        RoadReward(minutes: 10, kind: .scene, id: "sea", name: "海"),
        RoadReward(minutes: 20, kind: .sound, id: "rain", name: "雨の音"),
        RoadReward(minutes: 30, kind: .scene, id: "sunset", name: "夕焼け"),
        RoadReward(minutes: 40, kind: .sound, id: "waves", name: "波の音"),
        RoadReward(minutes: 50, kind: .scene, id: "snow", name: "雪山"),
        RoadReward(minutes: 60, kind: .sound, id: "birds", name: "森と小鳥"),
        RoadReward(minutes: 70, kind: .scene, id: "stars", name: "星空"),
        RoadReward(minutes: 80, kind: .sound, id: "bowl", name: "クリスタルボウル"),
        RoadReward(minutes: 90, kind: .scene, id: "sakura", name: "桜"),
        RoadReward(minutes: 100, kind: .sound, id: "freq", name: "やさしい周波数"),
        RoadReward(minutes: 110, kind: .scene, id: "fall", name: "滝"),
    ]

    static func next(after minutes: Int) -> RoadReward? { all.first { $0.minutes > minutes } }

    /// えらべる音（なし ＋ ひらいたもの）
    static func sounds(breathMinutes: Int) -> [(id: String, name: String)] {
        [("none", "なし")] + all.filter { $0.kind == .sound && $0.minutes <= breathMinutes }.map { ($0.id, $0.name) }
    }
}

/// 景色1枚（写真があれば写真、なければグラデーション＋名前）
struct SceneBackdrop: View {
    let scene: NatureScene

    var body: some View {
        GeometryReader { g in
            ZStack {
                if let img = scene.image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: g.size.width, height: g.size.height)
                        .clipped()
                } else {
                    LinearGradient(colors: scene.colors, startPoint: .top, endPoint: .bottom)
                    if scene.id == "stars" {
                        ForEach(0..<40, id: \.self) { i in
                            Circle().fill(Color.white.opacity(0.4 + 0.5 * Double((i * 37) % 10) / 10))
                                .frame(width: CGFloat(1 + (i * 7) % 3), height: CGFloat(1 + (i * 7) % 3))
                                .position(x: g.size.width * CGFloat((i * 53) % 100) / 100,
                                          y: g.size.height * 0.6 * CGFloat((i * 29) % 100) / 100)
                        }
                    }
                    // 遠くの山なみ
                    Ellipse().fill(scene.colors[0].opacity(0.55))
                        .frame(width: g.size.width * 1.6, height: g.size.height * 0.5)
                        .position(x: g.size.width * 0.2, y: g.size.height * 0.98)
                    Ellipse().fill(scene.colors[0].opacity(0.8))
                        .frame(width: g.size.width * 1.4, height: g.size.height * 0.42)
                        .position(x: g.size.width * 0.95, y: g.size.height * 1.04)
                }
            }
        }
    }
}
