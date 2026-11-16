import SwiftUI
import SafariServices

/// アプリ内Safari。Safariのコンテンツブロッカーが効き、インスタアプリに飛ばされない
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    /// 右上の「完了」を押したとき
    var onFinish: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {
        context.coordinator.onFinish = onFinish
    }

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        var onFinish: (() -> Void)?
        init(onFinish: (() -> Void)?) { self.onFinish = onFinish }
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) { onFinish?() }
    }
}
