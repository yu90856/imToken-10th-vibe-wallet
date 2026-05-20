import SwiftUI
import UIKit

/// 讓 Token Core 的 WKWebView 掛在視圖階層上（1×1 隱藏）
struct TokenCoreWebHost: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        Task { @MainActor in
            TokenCoreBridge.shared.attach(to: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        Task { @MainActor in
            TokenCoreBridge.shared.attach(to: uiView)
        }
    }
}
