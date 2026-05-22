import Foundation

/// 讀取 `Config/Secrets.plist`（勿提交含真實金鑰的檔案）
enum SecretsReader {
    static func string(for key: String) -> String? {
        guard let plist = loadPlist() else { return nil }
        guard let raw = plist[key] as? String else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !isPlaceholder(value) else { return nil }
        return value
    }

    static var hasBitrefillAPIKey: Bool {
        string(for: "BITREFILL_API_KEY") != nil
    }

    private static func isPlaceholder(_ value: String) -> Bool {
        let lower = value.lowercased()
        let markers = ["your_", "paste", "replace", "example", "xxx", "todo", "填入", "請填"]
        return markers.contains { lower.contains($0) }
    }

    private static func loadPlist() -> [String: Any]? {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "Secrets", withExtension: "plist", subdirectory: "Config"),
            Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            developmentSecretsURL(),
        ]
        for url in candidates.compactMap({ $0 }) {
            if let dict = readPlist(at: url) {
                return dict
            }
        }
        return nil
    }

    /// Xcode Run 時若未複製進 bundle，改讀專案內 Config/Secrets.plist
    private static func developmentSecretsURL() -> URL? {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment["SRCROOT"]
        if let root = env, !root.isEmpty {
            let url = URL(fileURLWithPath: root)
                .appendingPathComponent("VibeWallet/Config/Secrets.plist")
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        #endif
        return nil
    }

    private static func readPlist(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        return dict
    }
}
