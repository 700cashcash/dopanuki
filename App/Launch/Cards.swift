import SwiftUI
import CoreImage.CIFilterBuiltins

/// カードのQRに入れる中身。App Storeのリンクができたら差しかえる
enum ShareInfo {
    static let qrText = "ドパ抜き｜SNSを置いて、時間を取り戻すアプリ #ドパ抜きチャレンジ"
    static let invite = "いっしょにスマホ置こ！ ドパ抜きってアプリで、SNSを止めた時間を記録してるよ #ドパ抜きチャレンジ"
}

/// QRコード（端末の中で作る）
struct QRView: View {
    let text: String
    var body: some View {
        if let img = Self.make(text) {
            Image(uiImage: img).interpolation(.none).resizable().scaledToFit()
        } else {
            Color.white
        }
    }

    static func make(_ text: String) -> UIImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(text.utf8)
        f.correctionLevel = "M"
        guard let out = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cg = CIContext().createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// 縦長のシェアカード（宣言・結果・キモ朝・もどった・週まとめ）
struct ShareCard: View {
    let card: SavedCard
    let name: String

    private var bg: Color {
        switch card.kind {
        case .declare: return DP.purple
        case .result: return Color(hex: 0x1E9E5E)
        case .kimo: return Color(hex: 0x4A4458)
        case .back: return Color(hex: 0xE8661E)
        case .week: return Color(hex: 0x2F6BD0)
        case .milestone: return Color(hex: 0xE0A400)
        }
    }

    var body: some View {
        if card.kind == .result || card.kind == .milestone {
            BoardingPass(card: card, name: name)
        } else {
            poster
        }
    }

    private var poster: some View {
        ZStack(alignment: .topLeading) {
            bg
            Blob(color: DP.pink.opacity(card.kind == .kimo ? 0.35 : 0.9), size: 300, period: 10).offset(x: 170, y: -110)
            Blob(color: DP.yellow.opacity(card.kind == .kimo ? 0.3 : 0.85), size: 240, period: 12, offset: 0.4).offset(x: -110, y: 400)
            VStack(alignment: .leading, spacing: 8) {
                Text(label).font(.dp(14, .heavy)).foregroundColor(.white.opacity(0.85))
                content
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        if card.kind == .declare {
                            Text("用事はLINEか電話でね").font(.dp(13, .heavy)).foregroundColor(.white)
                        }
                        Text("#ドパ抜きチャレンジ").font(.dp(13, .heavy)).foregroundColor(.white.opacity(0.9))
                        Text(dateText).font(.dp(10, .bold)).foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    QRView(text: ShareInfo.qrText)
                        .frame(width: 58, height: 58)
                        .padding(5)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                }
            }
            .padding(22)
            DogView(size: 150, mood: mood, blinks: false, pose: DogPose(paw: card.kind == .result || card.kind == .back),
                    kimo: card.kind == .kimo ? (Int(card.text) ?? 2) : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 10)
                .offset(y: 40)
        }
        .frame(width: 320, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var mood: DogMood {
        switch card.kind {
        case .declare: return .sleep
        case .kimo: return .normal
        default: return .happy
        }
    }

    private var label: String {
        switch card.kind {
        case .declare: return "📣 宣言"
        case .result: return "🎉 取り戻した"
        case .kimo: return "☁️ 夜ふかしした朝"
        case .back: return "✨ もどった！"
        case .week: return "🗓️ 今週のまとめ"
        case .milestone: return "🏆 記念"
        }
    }

    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy.M.d"
        return f.string(from: card.date)
    }

    @ViewBuilder private var content: some View {
        switch card.kind {
        case .declare:
            Text("\(name)は いま、\nぼくと SNSおやすみ中！").font(.dp(26, .black)).foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(card.text).font(.num(30)).foregroundColor(DP.yellow)
            if !card.purpose.isEmpty {
                Text("（\(card.purpose)するよ）").font(.dp(15, .heavy)).foregroundColor(.white.opacity(0.85))
            }
        case .result:
            Text("SNSから").font(.dp(20, .heavy)).foregroundColor(.white)
            minutesText(card.minutes)
            Text(card.purpose.isEmpty ? "取り戻した" : "取り戻して、\(card.purpose)した").font(.dp(20, .heavy)).foregroundColor(.white)
        case .kimo:
            Text("ゆうべ、\nちょっと夜ふかし…").font(.dp(26, .black)).foregroundColor(.white)
            Text("今夜はいっしょに ねよ").font(.dp(15, .heavy)).foregroundColor(.white.opacity(0.85))
        case .back:
            Text("ちゃんと ねたら\nツヤツヤに もどった！").font(.dp(26, .black)).foregroundColor(.white)
        case .milestone:
            Text(card.text).font(.dp(30, .black)).foregroundColor(.white)
        case .week:
            Text("今週は").font(.dp(20, .heavy)).foregroundColor(.white)
            Text(card.text).font(.dp(34, .black)).foregroundColor(DP.yellow)
            Text("取り戻した（\(card.minutes / 60)時間\(card.minutes % 60)分）").font(.dp(16, .heavy)).foregroundColor(.white)
        }
    }

    private func minutesText(_ m: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if m >= 60 {
                Text("\(m / 60)").font(.num(76)).foregroundColor(DP.yellow)
                Text("時間").font(.dp(22, .heavy)).foregroundColor(.white)
                if m % 60 > 0 {
                    Text("\(m % 60)").font(.num(44)).foregroundColor(DP.yellow)
                    Text("分").font(.dp(22, .heavy)).foregroundColor(.white)
                }
            } else {
                Text("\(m)").font(.num(76)).foregroundColor(DP.yellow)
                Text("分").font(.dp(22, .heavy)).foregroundColor(.white)
            }
        }
    }
}

/// カードを大きく見る＋シェア
struct CardDetailView: View {
    let card: SavedCard
    let name: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button { dismiss() } label: { CircleIcon(system: "xmark") }.buttonStyle(PressStyle())
                Spacer()
            }
            Spacer(minLength: 0)
            ShareCard(card: card, name: name)
                .scaleEffect(0.95)
                .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
            Spacer(minLength: 0)
            let img = renderCard(ShareCard(card: card, name: name))
            ShareLink(item: img, message: Text("#ドパ抜きチャレンジ"), preview: SharePreview("ドパ抜き", image: img)) {
                Label("シェアする", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PuffyStyle(color: .blue, height: 56))
        }
        .padding(20)
        .background(DP.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

/// 結果カード：搭乗券（ボーディングパス）風。FROM「SNS」→ TO「何する？」
struct BoardingPass: View {
    let card: SavedCard
    let name: String

    private var gold: Bool { card.kind == .milestone }
    private var ink: Color { gold ? Color(hex: 0x3A2A00) : Color(hex: 0x1A1A2E) }
    private var accent: Color { gold ? Color(hex: 0xE0A400) : DP.blue }
    private var flight: String { String(format: "DPN-%04d", card.number ?? 0) }
    private var to: String { gold ? card.text : (card.purpose.isEmpty ? "じぶんの時間" : card.purpose) }

    var body: some View {
        VStack(spacing: 0) {
            // 上：航空会社・便名
            HStack {
                Text("✈︎ DOPANUKI AIR").font(.system(size: 12, weight: .black)).foregroundColor(.white)
                Spacer()
                Text(flight).font(.system(size: 13, weight: .heavy, design: .monospaced)).foregroundColor(.white)
            }
            .padding(.horizontal, 20).frame(height: 44)
            .background(accent)

            VStack(alignment: .leading, spacing: 14) {
                Text(gold ? "MILESTONE PASS" : "BOARDING PASS").font(.system(size: 11, weight: .heavy)).foregroundColor(ink.opacity(0.5))
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FROM").font(.system(size: 10, weight: .heavy)).foregroundColor(ink.opacity(0.5))
                        Text("SNS").font(.system(size: 34, weight: .black)).foregroundColor(ink)
                    }
                    Spacer()
                    Image(systemName: "airplane").font(.system(size: 24, weight: .bold)).foregroundColor(accent)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("TO").font(.system(size: 10, weight: .heavy)).foregroundColor(ink.opacity(0.5))
                        Text(to).font(.system(size: to.count > 5 ? 20 : 30, weight: .black)).foregroundColor(ink)
                            .lineLimit(1).minimumScaleFactor(0.5)
                    }
                }
                HStack(alignment: .top) {
                    field("PASSENGER", name)
                    Spacer()
                    field("DATE", dateText)
                    Spacer()
                    field("GATE", "基地")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(gold ? "TOTAL" : "取り戻した時間").font(.system(size: 10, weight: .heavy)).foregroundColor(ink.opacity(0.5))
                    Text(minutesText).font(.system(size: 40, weight: .black)).foregroundColor(accent)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
            }
            .padding(20)

            // ミシン目
            ZStack {
                Rectangle().fill(Color.clear).frame(height: 24)
                Path { p in p.move(to: CGPoint(x: 16, y: 12)); p.addLine(to: CGPoint(x: 304, y: 12)) }
                    .stroke(ink.opacity(0.25), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                HStack {
                    Circle().fill(DP.bg).frame(width: 24, height: 24).offset(x: -12)
                    Spacer()
                    Circle().fill(DP.bg).frame(width: 24, height: 24).offset(x: 12)
                }
            }

            // 下：半券（バーコード・ドパ抜きちゃん）
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    barcode.frame(width: 170, height: 46)
                    Text("#ドパ抜きチャレンジ").font(.dp(11, .heavy)).foregroundColor(ink.opacity(0.6))
                }
                Spacer()
                DogView(size: 92, mood: .happy, blinks: false, pose: DogPose(paw: true))
                    .offset(y: 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
            Spacer(minLength: 0)
        }
        .frame(width: 320, height: 520)
        .background(gold ? Color(hex: 0xFFF4D6) : Color(hex: 0xF7F5EF))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 9, weight: .heavy)).foregroundColor(ink.opacity(0.5))
            Text(value).font(.system(size: 14, weight: .heavy)).foregroundColor(ink).lineLimit(1)
        }
    }

    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy.M.d"
        return f.string(from: card.date)
    }

    private var minutesText: String {
        let m = card.minutes
        return m >= 60 ? "\(m / 60)時間" + (m % 60 > 0 ? "\(m % 60)分" : "") : "\(m)分"
    }

    /// バーコード風の飾り（便名から作るので毎回同じ）
    private var barcode: some View {
        let seed = (card.number ?? 7) * 2654435761
        return HStack(spacing: 1.5) {
            ForEach(0..<44, id: \.self) { i in
                Rectangle().fill(ink)
                    .frame(width: CGFloat(1 + ((seed >> (i % 28)) ^ i) % 3))
            }
        }
    }
}
