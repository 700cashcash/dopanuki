import SwiftUI
import Charts

/// 記録：インスタのプロフィール風（上=数字、まん中=1週間のグラフ、下=カード）
struct LaunchRecordView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var life: LifeState
    @Binding var replayOpening: Bool
    @State private var opened: SavedCard?

    private let palette: [Color] = [DP.blue, DP.pink, DP.green, DP.yellow, DP.orange, DP.violet, Color(hex: 0x2FB8A8), DP.red]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                weekChart
                grid
                DexSection()
                TipJarCard().padding(.top, 6)
                Button { replayOpening = true } label: { Label("オープニングを見なおす", systemImage: "play.circle") }
                    .buttonStyle(PuffyStyle(color: .white, height: 46, strong: false))
                    .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.top, 52)
            .padding(.bottom, 24)
        }
        .background(TopGlow(color: DP.purple.opacity(0.5), reach: 0.35))
        .sheet(item: $opened) { c in CardDetailView(card: c, name: life.nameForCards(game)) }
    }

    // MARK: 上：ドパ抜きちゃん＋数字3つ

    private var header: some View {
        HStack(spacing: 14) {
            DogView(size: 86, mood: .happy, kimo: life.kimo, alive: true)
                .background(Circle().fill(DP.card2))
                .clipShape(Circle())
            HStack(spacing: 0) {
                stat(hm(life.todayMinutes), "きょう")
                stat(hm(life.totalMinutes), "これまで")
                stat("\(life.data.sleptNights)日", "ちゃんと寝た")
            }
        }
        .overlay(alignment: .topLeading) {
            Text(game.dogName).font(.dp(13, .heavy)).foregroundColor(DP.gray).offset(y: -26)
        }
    }

    private func stat(_ v: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(v).font(.num(17)).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.dp(11, .bold)).foregroundColor(DP.gray)
        }
        .frame(maxWidth: .infinity)
    }

    private func hm(_ m: Int) -> String { m >= 60 ? "\(m / 60)h\(m % 60)m" : "\(m)m" }

    // MARK: まん中：1週間（何する？ごとに色分け）

    private var weekChart: some View {
        let rows = life.week()
        let purposes = Array(Set(rows.map { $0.purpose }.filter { !$0.isEmpty })).sorted()
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "E"
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("この1週間").font(.dp(16, .heavy))
                Spacer()
                Text(LifeState.movies(rows.reduce(0) { $0 + $1.minutes }) + " 取り戻した")
                    .font(.dp(12, .heavy)).foregroundColor(DP.yellow)
            }
            Chart {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                    BarMark(x: .value("日", f.string(from: r.day)), y: .value("分", r.minutes))
                        .foregroundStyle(by: .value("何する？", r.purpose.isEmpty ? "—" : r.purpose))
                        .cornerRadius(4)
                }
            }
            .chartForegroundStyleScale(domain: purposes.isEmpty ? ["—"] : purposes + ["—"],
                                       range: purposes.isEmpty ? [Color.clear] : Array(palette.prefix(purposes.count)) + [Color.clear])
            .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine().foregroundStyle(Color.white.opacity(0.08)); AxisValueLabel() } }
            .chartLegend(position: .bottom, spacing: 8)
            .frame(height: 190)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DP.card))
    }

    // MARK: 下：カードがたまる

    private var grid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("カード").font(.dp(16, .heavy))
            if life.data.cards.isEmpty {
                Text("置いたり、ねたりすると カードがたまるよ").font(.dp(13, .bold)).foregroundColor(DP.gray)
                    .padding(.vertical, 20)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                ForEach(life.data.cards.reversed()) { c in
                    Button { opened = c } label: {
                        ShareCard(card: c, name: life.nameForCards(game))
                            .scaleEffect(0.33, anchor: .topLeading)
                            .frame(width: 320 * 0.33, height: 520 * 0.33, alignment: .topLeading)
                            .clipped()
                    }
                    .buttonStyle(PressStyle(scale: 0.95))
                }
            }
        }
    }
}
