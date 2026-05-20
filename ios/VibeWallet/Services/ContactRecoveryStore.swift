import Foundation
import Observation

/// 聯絡人解鎖：三組提示詞；Face ID 失敗時輸入其中兩組正確提示詞可解鎖，30 分鐘內不再上鎖
@Observable
final class ContactRecoveryStore {
    static let shared = ContactRecoveryStore()

    private enum Key {
        static let enabled = "contactRecovery.enabled"
        static let graceUntil = "contactRecovery.graceUntil"
        static let hintsAccount = "com.vibe.wallet.contactRecovery.hints"
    }

    static let gracePeriodSeconds: TimeInterval = 30 * 60

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Key.enabled) }
    }

    private(set) var hintCount: Int = 0

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: Key.enabled)
        reloadFromKeychain()
    }

    var isConfigured: Bool {
        isEnabled && hintCount == 3
    }

    var isInGracePeriod: Bool {
        guard let until = UserDefaults.standard.object(forKey: Key.graceUntil) as? Date else {
            return false
        }
        return until > Date()
    }

    var gracePeriodRemainingText: String? {
        guard let until = UserDefaults.standard.object(forKey: Key.graceUntil) as? Date,
              until > Date() else { return nil }
        let minutes = max(1, Int(until.timeIntervalSinceNow / 60))
        return "免鎖定剩餘約 \(minutes) 分鐘"
    }

    func reloadFromKeychain() {
        hintCount = loadHints().count
    }

    func save(hints: [String]) throws {
        let normalizedHints = normalizeHints(hints)
        guard normalizedHints.count == 3 else {
            throw ContactRecoveryError.invalidHints
        }

        let hintsJSON = try JSONEncoder().encode(normalizedHints)
        guard let hintsString = String(data: hintsJSON, encoding: .utf8) else {
            throw ContactRecoveryError.storageFailed
        }
        try WalletKeychainStore.saveSecurityItem(hintsString, account: Key.hintsAccount)

        hintCount = 3
        isEnabled = true
    }

    func disableAndClear() {
        isEnabled = false
        WalletKeychainStore.deleteSecurityItem(account: Key.hintsAccount)
        clearGracePeriod()
        hintCount = 0
    }

    func verify(hint1: String, hint2: String) -> Bool {
        let stored = Set(loadHints())
        guard stored.count == 3 else { return false }
        let a = normalize(hint1)
        let b = normalize(hint2)
        guard !a.isEmpty, !b.isEmpty, a != b else { return false }
        return stored.contains(a) && stored.contains(b)
    }

    func grantGracePeriod() {
        let until = Date().addingTimeInterval(Self.gracePeriodSeconds)
        UserDefaults.standard.set(until, forKey: Key.graceUntil)
    }

    func clearGracePeriod() {
        UserDefaults.standard.removeObject(forKey: Key.graceUntil)
    }

    // MARK: - Private

    private func loadHints() -> [String] {
        guard let raw = WalletKeychainStore.loadSecurityItem(account: Key.hintsAccount),
              let data = raw.data(using: .utf8),
              let hints = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return hints
    }

    private func normalizeHints(_ hints: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for hint in hints {
            let n = normalize(hint)
            guard !n.isEmpty, seen.insert(n).inserted else { continue }
            out.append(n)
        }
        return out
    }

    /// 僅去除首尾空白，保留中文與大小寫
    private func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ContactRecoveryError: LocalizedError {
    case invalidHints
    case storageFailed
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .invalidHints:
            return "請設定 3 組彼此不同的提示詞（支援中文，不可空白）。"
        case .storageFailed:
            return "無法儲存提示詞。"
        case .verificationFailed:
            return "提示詞不正確，請輸入任意兩組正確提示詞。"
        }
    }
}
