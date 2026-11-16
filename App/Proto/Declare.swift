import SwiftUI

/// 宣言カード（シェアする画像）。中断のことは書かない
struct DeclareCard: View {
    let name: String
    let when: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            DP.purple
            Blob(color: DP.pink, size: 260, period: 10).offset(x: 170, y: -90)
            Blob(color: DP.green.opacity(0.9), size: 220, period: 12, offset: 0.4).offset(x: -90, y: 260)
            Blob(color: DP.yellow, size: 90, period: 7, offset: 0.2).offset(x: 230, y: 250)
            VStack(alignment: .leading, spacing: 10) {
                Text("📣 宣言").font(.dp(13, .heavy)).foregroundColor(.white.opacity(0.85))
                Text("\(name)は いま、\nぼくと SNSおやすみ中！").font(.dp(26, .black)).foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(when).font(.num(30)).foregroundColor(DP.yellow)
                Spacer(minLength: 0)
                Text("用事はLINEか電話でね").font(.dp(14, .heavy)).foregroundColor(.white)
                Text("#ドパ抜きチャレンジ").font(.dp(13, .heavy)).foregroundColor(.white.opacity(0.8))
            }
            .padding(22)
            DogView(size: 130, mood: .sleep, blinks: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 14)
                .padding(.bottom, 10)
        }
        .frame(width: 320, height: 400)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

/// 宣言どおりクリアしたときのカード
struct ClearCard: View {
    let name: String
    let minutes: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: 0x1E9E5E)
            Blob(color: DP.yellow, size: 240, period: 10).offset(x: 180, y: -80)
            Blob(color: DP.blue.opacity(0.85), size: 220, period: 12, offset: 0.4).offset(x: -100, y: 250)
            VStack(alignment: .leading, spacing: 8) {
                Text("🎉 宣言どおりクリア！").font(.dp(16, .heavy)).foregroundColor(.white)
                Text("\(name)は SNSから").font(.dp(20, .heavy)).foregroundColor(.white)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(minutes >= 60 ? "\(minutes / 60)" : "\(minutes)").font(.num(72)).foregroundColor(DP.yellow)
                    Text(minutes >= 60 ? "時間\(minutes % 60 > 0 ? "\(minutes % 60)分" : "")" : "分").font(.dp(22, .heavy)).foregroundColor(.white)
                }
                Text("取り戻した").font(.dp(20, .heavy)).foregroundColor(.white)
                Spacer(minLength: 0)
                Text("#ドパ抜きチャレンジ").font(.dp(13, .heavy)).foregroundColor(.white.opacity(0.85))
            }
            .padding(22)
            DogView(size: 130, mood: .happy, blinks: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 14)
                .padding(.bottom, 10)
        }
        .frame(width: 320, height: 400)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

@MainActor
func renderCard<V: View>(_ view: V) -> Image {
    let r = ImageRenderer(content: view)
    r.scale = 3
    if let ui = r.uiImage { return Image(uiImage: ui) }
    return Image(systemName: "photo")
}

/// 宣言してから はじめる画面
struct DeclareView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var life: LifeState
    @State private var shared = false
    @FocusState private var nameFocus: Bool

    private var when: String { game.pendingPlan?.cardWhen ?? "" }
    private var shareText: String { "\(game.userName)は いま SNSおやすみ中！ \(when) 用事はLINEか電話でね #ドパ抜きチャレンジ" }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button { game.pendingPlan = nil; game.flow = .pick } label: { CircleIcon(system: "chevron.left") }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel(Text("もどる"))
                Spacer()
            }
            Text("宣言しよう").font(.dp(30, .heavy)).frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Text("なまえ").font(.dp(13, .heavy)).foregroundColor(DP.gray)
                TextField("わたし", text: $game.userName)
                    .font(.dp(16, .heavy))
                    .focused($nameFocus)
                    .submitLabel(.done)
                Image(systemName: "pencil").foregroundColor(DP.gray)
            }
            .padding(.horizontal, 14).frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(DP.card))

            Group {
                if AppMode.launch {
                    ShareCard(card: launchCard, name: displayName)
                        .scaleEffect(0.7)
                        .frame(width: 224, height: 364)
                } else {
                    DeclareCard(name: displayName, when: when)
                        .scaleEffect(0.92)
                }
            }
            .shadow(color: DP.purple.opacity(0.6), radius: 24, y: 12)

            Spacer(minLength: 0)

            if shared {
                Button { begin() } label: { Label("はじめる", systemImage: "play.fill") }
                    .buttonStyle(PuffyStyle(color: .blue, height: 58))
                ShareLink(item: card, message: Text(shareText), preview: SharePreview("ドパ抜き 宣言", image: card)) {
                    Text("もう一度シェア")
                }
                .font(.dp(14, .heavy))
                .foregroundColor(DP.gray)
            } else {
                ShareLink(item: card, message: Text(shareText), preview: SharePreview("ドパ抜き 宣言", image: card)) {
                    Label("シェアしてはじめる", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PuffyStyle(color: .blue, height: 58))
                .simultaneousGesture(TapGesture().onEnded {
                    // シェア画面からもどったら「はじめる」を押す
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { shared = true }
                })
                Button("シェアせずにはじめる") { begin() }
                    .font(.dp(14, .heavy))
                    .foregroundColor(DP.gray)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(TopGlow(color: DP.purple.opacity(0.6), reach: 0.5))
        .onTapGesture { nameFocus = false }
    }

    private var launchCard: SavedCard {
        SavedCard(kind: .declare, purpose: game.pendingPlan?.purpose ?? "", text: when)
    }

    private var card: Image {
        AppMode.launch ? renderCard(ShareCard(card: launchCard, name: displayName))
                       : renderCard(DeclareCard(name: displayName, when: when))
    }

    /// 宣言カードを記録にのこして、はじめる
    private func begin() {
        if AppMode.launch { life.addCard(launchCard) }
        game.beginDeclared()
    }

    private var displayName: String {
        let n = game.userName.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "わたし" : n
    }
}
