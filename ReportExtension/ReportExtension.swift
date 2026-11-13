import DeviceActivity
import SwiftUI

/// スクリーンタイム表示用の拡張。iOSの仕様で、利用時間のデータはこの拡張の中でしか扱えない
/// （アプリ本体には数字を持ち出せない。表示した画面だけがアプリに埋め込まれる）
@main
struct ReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { summary in TotalActivityView(summary: summary) }
    }
}

extension DeviceActivityReport.Context {
    static let totalActivity = Self("totalActivity")
}

struct UsageSummary {
    struct AppUsage: Identifiable {
        let id = UUID()
        let name: String
        let duration: TimeInterval
    }
    let total: TimeInterval
    let apps: [AppUsage]
}

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (UsageSummary) -> TotalActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> UsageSummary {
        var total: TimeInterval = 0
        var perApp: [String: TimeInterval] = [:]
        for await deviceData in data {
            for await segment in deviceData.activitySegments {
                total += segment.totalActivityDuration
                for await category in segment.categories {
                    for await app in category.applications {
                        let name = app.application.localizedDisplayName ?? "その他"
                        perApp[name, default: 0] += app.totalActivityDuration
                    }
                }
            }
        }
        let apps = perApp
            .map { UsageSummary.AppUsage(name: $0.key, duration: $0.value) }
            .sorted { $0.duration > $1.duration }
            .prefix(5)
        return UsageSummary(total: total, apps: Array(apps))
    }
}

struct TotalActivityView: View {
    let summary: UsageSummary

    private func format(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        return m >= 60 ? "\(m / 60)時間\(m % 60)分" : "\(m)分"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日のスクリーンタイム").font(.caption).foregroundStyle(.secondary)
            Text(format(summary.total)).font(.largeTitle.bold())
            ForEach(summary.apps) { app in
                HStack {
                    Text(app.name)
                    Spacer()
                    Text(format(app.duration)).foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
        .padding()
    }
}
