import SwiftUI
import WebKit

/// 內嵌 DApp 瀏覽器，注入 EIP-1193 `window.ethereum`（Sepolia + 本機地址）
struct DAppBrowserView: View {
    let initialURL: URL
    let walletAddress: String
    let chainIdHex: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var canGoBack = false
    @State private var isLoading = true
    @State private var pageTitle = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("載入中…")
                        .padding(8)
                }
                DAppWebView(
                    url: initialURL,
                    walletAddress: walletAddress,
                    chainIdHex: chainIdHex,
                    canGoBack: $canGoBack,
                    isLoading: $isLoading,
                    pageTitle: $pageTitle
                )
            }
            .background(AppTheme.pageBackground(for: colorScheme))
            .navigationTitle(pageTitle.isEmpty ? "Dapp" : pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("關閉") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Text(ChainConfig.active.shortName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                        if canGoBack {
                            Button("返回") {
                                NotificationCenter.default.post(name: .dappBrowserGoBack, object: nil)
                            }
                        }
                    }
                }
            }
        }
    }
}

extension Notification.Name {
    static let dappBrowserGoBack = Notification.Name("dappBrowserGoBack")
}

// MARK: - WKWebView

private struct DAppWebView: UIViewRepresentable {
    let url: URL
    let walletAddress: String
    let chainIdHex: String
    @Binding var canGoBack: Bool
    @Binding var isLoading: Bool
    @Binding var pageTitle: String

    func makeCoordinator() -> Coordinator {
        Coordinator(
            walletAddress: walletAddress,
            chainIdHex: chainIdHex,
            canGoBack: $canGoBack,
            isLoading: $isLoading,
            pageTitle: $pageTitle
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "vibeEthereum")
        let script = EthereumProviderScript.make(
            chainIdHex: chainIdHex,
            address: walletAddress
        )
        controller.addUserScript(
            WKUserScript(
                source: script,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )
        config.userContentController = controller
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.webView = webView

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.goBackNotification),
            name: .dappBrowserGoBack,
            object: nil
        )

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let walletAddress: String
        let chainIdHex: String
        @Binding var canGoBack: Bool
        @Binding var isLoading: Bool
        @Binding var pageTitle: String
        weak var webView: WKWebView?

        init(
            walletAddress: String,
            chainIdHex: String,
            canGoBack: Binding<Bool>,
            isLoading: Binding<Bool>,
            pageTitle: Binding<String>
        ) {
            self.walletAddress = walletAddress
            self.chainIdHex = chainIdHex
            _canGoBack = canGoBack
            _isLoading = isLoading
            _pageTitle = pageTitle
        }

        @objc func goBackNotification() {
            webView?.goBack()
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "vibeEthereum",
                  let body = message.body as? [String: Any],
                  let requestId = body["id"] as? String,
                  let method = body["method"] as? String else { return }

            Task { @MainActor in
                let result = await handle(method: method, params: body["params"] as? [Any] ?? [])
                respond(requestId: requestId, result: result.value, error: result.error)
            }
        }

        private struct RPCResult {
            let value: String?
            let error: String?
        }

        @MainActor
        private func handle(method: String, params: [Any]) async -> RPCResult {
            switch method {
            case "eth_requestAccounts", "eth_accounts":
                return RPCResult(value: encodeJSON([walletAddress]), error: nil)
            case "eth_chainId":
                return RPCResult(value: "\"\(chainIdHex)\"", error: nil)
            case "net_version":
                let decimal = UInt64(chainIdHex.dropFirst(2), radix: 16).map(String.init) ?? "11155111"
                return RPCResult(value: "\"\(decimal)\"", error: nil)
            case "wallet_switchEthereumChain", "wallet_addEthereumChain":
                return RPCResult(value: "null", error: nil)
            case "personal_sign", "eth_sign", "eth_signTypedData_v4", "eth_sendTransaction":
                return RPCResult(
                    value: nil,
                    error: "Vibe Wallet 示範版：請在正式版完成簽名確認"
                )
            default:
                return RPCResult(value: "null", error: nil)
            }
        }

        private func respond(requestId: String, result: String?, error: String?) {
            guard let webView else { return }
            let errLiteral = error.map { "\"\($0.replacingOccurrences(of: "\"", with: "\\\"")))\"" } ?? "null"
            let resLiteral = result ?? "null"
            let script = "window.ethereum._handleResponse('\(requestId)', \(resLiteral), \(errLiteral));"
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        private func encodeJSON(_ object: Any) -> String? {
            guard let data = try? JSONSerialization.data(withJSONObject: object),
                  let str = String(data: data, encoding: .utf8) else { return nil }
            return str
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
            canGoBack = webView.canGoBack
            pageTitle = webView.title ?? webView.url?.host ?? "Dapp"
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }
    }
}

// MARK: - Injected provider

private enum EthereumProviderScript {
    static func make(chainIdHex: String, address: String) -> String {
        """
        (function() {
          if (window.ethereum && window.ethereum.isVibeWallet) return;
          var _pending = {};
          var _id = 0;
          var _selected = '\(address.lowercased())';
          window.ethereum = {
            isMetaMask: true,
            isVibeWallet: true,
            chainId: '\(chainIdHex)',
            selectedAddress: _selected,
            request: function(args) {
              return new Promise(function(resolve, reject) {
                var rid = String(++_id);
                _pending[rid] = { resolve: resolve, reject: reject };
                window.webkit.messageHandlers.vibeEthereum.postMessage({
                  id: rid,
                  method: args.method,
                  params: args.params || []
                });
              });
            },
            on: function() {},
            removeListener: function() {},
            _handleResponse: function(id, result, error) {
              var p = _pending[id];
              if (!p) return;
              delete _pending[id];
              if (error) p.reject(new Error(error));
              else p.resolve(result);
            }
          };
          window.dispatchEvent(new Event('ethereum#initialized'));
        })();
        """
    }
}
