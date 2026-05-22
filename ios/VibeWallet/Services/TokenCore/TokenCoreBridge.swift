import Foundation
import OSLog
@preconcurrency import WebKit

private let tokenCoreLog = Logger(subsystem: "com.vibe.wallet", category: "TokenCore")

enum TokenCoreConsole {
    static func log(_ message: String) {
        tokenCoreLog.info("\(message, privacy: .public)")
        #if DEBUG
        print("[TokenCore] \(message)")
        #endif
    }
}

/// 在 WKWebView 中執行 @consenlabs/tcx-wasm（與 Web 版 `tokenCore.ts` 相同 WASM）
@MainActor
final class TokenCoreBridge: NSObject {
    static let shared = TokenCoreBridge()
    private static let entryURL = URL(string: "\(TokenCoreSchemeHandler.scheme)://local/token_core_host.html")!

    private var webView: WKWebView?
    private weak var hostView: UIView?
    private var isReady = false
    private var isPageReady = false
    private var loadError: String?
    private var readyWaiters: [CheckedContinuation<Void, Error>] = []
    private var callWaiters: [String: CheckedContinuation<String, Error>] = [:]

    nonisolated private override init() {
        super.init()
    }

    func attach(to host: UIView) {
        initializeIfNeeded()
        guard let webView, webView.superview !== host else { return }
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.widthAnchor.constraint(equalToConstant: 1),
            webView.heightAnchor.constraint(equalToConstant: 1),
            webView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])
        hostView = host
    }

    func initializeIfNeeded() {
        guard webView == nil else { return }

        guard Self.wasmData() != nil, TokenCoreSchemeHandler.loadBundledFile(named: "tcx_wasm.js") != nil else {
            loadError = "找不到 Token Core 資源（請執行 ios/scripts/sync-token-core-ios.sh 後重新編譯）"
            TokenCoreConsole.log("錯誤：缺少 WASM / JS 資源")
            return
        }
        TokenCoreConsole.log("開始初始化 WebView…")

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let controller = WKUserContentController()
        controller.add(self, name: "tokenCore")
        config.userContentController = controller
        config.setURLSchemeHandler(TokenCoreSchemeHandler(), forURLScheme: TokenCoreSchemeHandler.scheme)
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        let view = WKWebView(frame: .zero, configuration: config)
        view.isHidden = true
        view.navigationDelegate = self
        webView = view

        view.load(URLRequest(url: Self.entryURL))
    }

    private static func wasmData() -> Data? {
        TokenCoreSchemeHandler.loadBundledFile(named: "tcx_wasm_bg.wasm")
    }

    func ensureReady() async throws {
        initializeIfNeeded()
        if let loadError { throw TokenCoreError.bridgeFailed(loadError) }
        if isReady { return }

        try await raceWithTimeout(seconds: 45) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.readyWaiters.append(continuation)
            }
        }
    }

    private func bootWasmIfNeeded() {
        guard isPageReady, !isReady, loadError == nil, let webView else { return }
        guard let wasm = Self.wasmData() else {
            failWarmup("找不到 tcx_wasm_bg.wasm")
            return
        }

        let base64 = wasm.base64EncodedString()
        // 單次 evaluate 過大時改分塊（約 2.3MB WASM）
        TokenCoreConsole.log("HTML 就緒，注入 WASM（\(wasm.count) bytes）…")
        if base64.count > 900_000 {
            TokenCoreConsole.log("使用分塊注入 WASM")
            bootWasmChunked(base64, webView: webView)
        } else {
            let script = "window.__bootTokenCore('\(base64)');"
            webView.evaluateJavaScript(script) { _, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let error {
                        self.failWarmup("WASM 注入失敗：\(error.localizedDescription)")
                    }
                }
            }
        }
    }

    /// base64 字元集不含 `"`、`\`，可直接嵌入 JS 字串（勿用 JSONSerialization 包 String）。
    private nonisolated static func pushWasmChunkScript(_ base64Chunk: String) -> String {
        "window.__pushWasmChunk(\"\(base64Chunk)\");"
    }

    private func bootWasmChunked(_ base64: String, webView: WKWebView) {
        TokenCoreConsole.log("bootWasmChunked v2（直接注入 base64，無 JSONSerialization）")
        webView.evaluateJavaScript("window.__wasmChunks=[];") { _, _ in
            Task { @MainActor [weak self] in
                self?.pushWasmChunks(from: base64.startIndex, base64: base64, webView: webView)
            }
        }
    }

    @MainActor
    private func pushWasmChunks(from start: String.Index, base64: String, webView: WKWebView) {
        guard start < base64.endIndex else {
            webView.evaluateJavaScript("window.__bootTokenCoreChunked();") { _, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let error {
                        self.failWarmup("WASM 分塊注入失敗：\(error.localizedDescription)")
                    }
                }
            }
            return
        }
        let chunkSize = 400_000
        let end = base64.index(start, offsetBy: chunkSize, limitedBy: base64.endIndex) ?? base64.endIndex
        let chunk = String(base64[start..<end])
        let script = Self.pushWasmChunkScript(chunk)
        webView.evaluateJavaScript(script) { _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    self.failWarmup("WASM 分塊失敗：\(error.localizedDescription)")
                } else {
                    self.pushWasmChunks(from: end, base64: base64, webView: webView)
                }
            }
        }
    }

    func call(_ op: String, payload: [String: Any] = [:]) async throws -> String {
        try await ensureReady()
        guard let webView else { throw TokenCoreError.bridgeFailed("WebView 未建立") }

        TokenCoreConsole.log("呼叫 \(op)…")
        let id = UUID().uuidString
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        guard let payloadJSON = String(data: payloadData, encoding: .utf8) else {
            throw TokenCoreError.bridgeFailed("參數編碼失敗")
        }

        return try await raceWithTimeout(seconds: 90) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                self.callWaiters[id] = continuation
                let script = "window.__runTokenCore('\(id)', '\(op)', \(payloadJSON));"
                webView.evaluateJavaScript(script) { _, error in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if let error,
                           let pending = self.callWaiters.removeValue(forKey: id) {
                            pending.resume(
                                throwing: TokenCoreError.bridgeFailed(error.localizedDescription)
                            )
                        }
                    }
                }
            }
        }
    }

    @MainActor
    private func raceWithTimeout<T: Sendable>(
        seconds: Double,
        _ operation: @escaping @Sendable @MainActor () async throws -> T
    ) async throws -> T {
        let clock = ContinuousClock()
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await clock.sleep(for: .seconds(seconds))
                throw TokenCoreError.bridgeFailed("操作逾時，請稍後再試")
            }
            guard let value = try await group.next() else {
                throw TokenCoreError.bridgeFailed("Token Core 無回應")
            }
            group.cancelAll()
            return value
        }
    }

    private func failAllCalls(_ message: String) {
        let error = TokenCoreError.bridgeFailed(message)
        callWaiters.values.forEach { $0.resume(throwing: error) }
        callWaiters.removeAll()
    }
}

extension TokenCoreBridge: WKScriptMessageHandler {
    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        Task { @MainActor in
            processScriptMessage(message)
        }
    }

    @MainActor
    private func processScriptMessage(_ message: WKScriptMessage) {
        guard message.name == "tokenCore" else { return }
        handleScriptMessageBody(message.body)
    }

    @MainActor
    private func handleScriptMessageBody(_ body: Any) {
        guard let payload = body as? [String: Any] else { return }
        handleMessage(payload)
    }

    private func handleMessage(_ body: [String: Any]) {
        if let type = body["type"] as? String {
            switch type {
            case "pageReady":
                isPageReady = true
                TokenCoreConsole.log("HTML pageReady")
                bootWasmIfNeeded()
            case "ready":
                isReady = true
                loadError = nil
                TokenCoreConsole.log("WASM 就緒 ✓")
                readyWaiters.forEach { $0.resume() }
                readyWaiters.removeAll()
            case "error":
                failWarmup(body["error"] as? String ?? "Token Core 初始化失敗")
            default:
                break
            }
            return
        }

        guard let id = body["id"] as? String,
              let continuation = callWaiters.removeValue(forKey: id) else { return }

        if body["ok"] as? Bool == true, let result = body["result"] as? String {
            TokenCoreConsole.log("完成 \(id.prefix(8))…")
            continuation.resume(returning: result)
        } else {
            let err = body["error"] as? String ?? "Token Core 呼叫失敗"
            TokenCoreConsole.log("失敗：\(err)")
            continuation.resume(throwing: TokenCoreError.bridgeFailed(err))
        }
    }
}

extension TokenCoreBridge: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            failWarmup(error.localizedDescription)
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        Task { @MainActor in
            failWarmup(error.localizedDescription)
        }
    }

    nonisolated func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        Task { @MainActor in
            TokenCoreConsole.log("⚠️ WebContent 程序被系統終止（常見於記憶體不足）")
            isReady = false
            isPageReady = false
            failWarmup("Token Core 程序已結束，請關閉 App 後重新開啟")
            webView.reload()
        }
    }

    private func failWarmup(_ message: String) {
        loadError = message
        tokenCoreLog.error("warmup failed: \(message, privacy: .public)")
        #if DEBUG
        print("[TokenCore] warmup failed:", message)
        #endif
        let error = TokenCoreError.bridgeFailed(message)
        readyWaiters.forEach { $0.resume(throwing: error) }
        readyWaiters.removeAll()
        failAllCalls(message)
    }
}

enum TokenCoreError: LocalizedError {
    case bridgeFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .bridgeFailed(let message):
            return message
        case .invalidResponse:
            return "Token Core 回傳格式無法解析。"
        }
    }
}
