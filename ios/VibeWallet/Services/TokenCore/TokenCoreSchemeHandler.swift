import Foundation
import WebKit

/// 提供 Bundle 內 Token Core 的 .js / .html（WASM 由 Swift 直接注入，不走 fetch）
final class TokenCoreSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "vibetokencore"

    private let lock = NSLock()
    private var activeTasks = Set<ObjectIdentifier>()

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let taskId = ObjectIdentifier(urlSchemeTask)
        lock.lock()
        activeTasks.insert(taskId)
        lock.unlock()

        guard let (response, data) = Self.makeResponse(for: urlSchemeTask.request.url) else {
            urlSchemeTask.didFailWithError(
                NSError(
                    domain: "TokenCoreScheme",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "找不到資源"]
                )
            )
            removeTask(taskId)
            return
        }

        urlSchemeTask.didReceive(response)
        if !data.isEmpty {
            urlSchemeTask.didReceive(data)
        }
        urlSchemeTask.didFinish()
        removeTask(taskId)
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        removeTask(ObjectIdentifier(urlSchemeTask))
    }

    private func removeTask(_ id: ObjectIdentifier) {
        lock.lock()
        activeTasks.remove(id)
        lock.unlock()
    }

    private static func makeResponse(for url: URL?) -> (URLResponse, Data)? {
        guard let url, url.scheme == scheme else { return nil }

        let rawPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let fileName: String
        switch rawPath {
        case "", "index.html", "token_core_host.html":
            fileName = "token_core_host.html"
        case "tcx_wasm.js":
            fileName = "tcx_wasm.js"
        default:
            fileName = rawPath
        }

        guard fileName != "tcx_wasm_bg.wasm",
              let data = loadBundledFile(named: fileName) else {
            return nil
        }

        let mime = mimeType(for: fileName)
        let headers = [
            "Content-Type": mime,
            "Content-Length": "\(data.count)",
        ]
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) else {
            return nil
        }
        return (response, data)
    }

    static func loadBundledFile(named name: String) -> Data? {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        if let url = Bundle.main.url(forResource: base, withExtension: ext, subdirectory: "TokenCore"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        if let url = Bundle.main.url(forResource: base, withExtension: ext),
           let data = try? Data(contentsOf: url) {
            return data
        }
        return nil
    }

    private static func mimeType(for fileName: String) -> String {
        switch (fileName as NSString).pathExtension.lowercased() {
        case "html": return "text/html; charset=utf-8"
        case "js": return "application/javascript; charset=utf-8"
        default: return "application/octet-stream"
        }
    }
}
