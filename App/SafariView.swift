import SwiftUI
import SafariServices

/// アプリ内Safari。Safariのコンテンツブロッカーが効き、インスタアプリに飛ばされない
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
