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
        }
    }

    var body: some View {
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
