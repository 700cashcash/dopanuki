import SwiftUI
import StoreKit

/// 投げ銭（消耗型のアプリ内課金）。有料機能はなし、開発の応援だけ
@MainActor
final class TipJar: ObservableObject {
    static let ids = ["com.isk.dopanuki.tip.small", "com.isk.dopanuki.tip.medium", "com.isk.dopanuki.tip.large"]
    @Published var products: [Product] = []
    @Published var loaded = false
    @Published var thanks = false
    @Published var buying: String?

    func load() async {
        guard !loaded else { return }
        let p = (try? await Product.products(for: Self.ids)) ?? []
        products = p.sorted { $0.price < $1.price }
        loaded = true
    }

    func buy(_ p: Product) async {
        buying = p.id
        defer { buying = nil }
        guard let r = try? await p.purchase() else { return }
        if case .success(let v) = r, case .verified(let t) = v {
            await t.finish()
            thanks = true
        }
    }
}

/// 「ドパ抜きちゃんに おやつをあげる」
struct TipJarCard: View {
    @StateObject private var jar = TipJar()
    private let snacks = ["🍪", "🍩", "🍰"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                DogView(size: 56, mood: jar.thanks ? .happy : .normal, pose: DogPose(paw: jar.thanks))
                VStack(alignment: .leading, spacing: 3) {
                    Text("ドパ抜きちゃんに おやつをあげる").font(.dp(15, .heavy))
                    Text(jar.thanks ? "おいしい〜！ ほんとに ありがと！" : "開発の応援。もらえるものは ふえないよ")
                        .font(.dp(12, .bold)).foregroundColor(jar.thanks ? DP.yellow : DP.gray)
                }
            }
            if jar.products.isEmpty {
                Text(jar.loaded ? "準備中" : "よみこみ中…").font(.dp(13, .heavy)).foregroundColor(DP.dim)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
            } else {
                HStack(spacing: 8) {
                    ForEach(Array(jar.products.enumerated()), id: \.element.id) { i, p in
                        Button { Task { await jar.buy(p) } } label: {
                            VStack(spacing: 4) {
                                Text(snacks[min(i, 2)]).font(.system(size: 26))
                                Text(p.displayPrice).font(.dp(13, .heavy))
                            }
                            .frame(maxWidth: .infinity).frame(height: 70)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.08)))
                            .overlay { if jar.buying == p.id { ProgressView().tint(.white) } }
                        }
                        .buttonStyle(PressStyle())
                        .disabled(jar.buying != nil)
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DP.card))
        .task { await jar.load() }
        .onChange(of: jar.thanks) { t in if t { Haptic.success() } }
    }
}
