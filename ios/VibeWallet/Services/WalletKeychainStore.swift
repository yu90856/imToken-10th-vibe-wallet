import Foundation
import Security

enum WalletKeychainStore {
    private static let service = "com.vibe.wallet.keychain"
    private static let accountKey = "com.vibe.wallet.keystore"
    private static let pendingKeystoreKey = "com.vibe.wallet.keystore.pending"
    private static let mnemonicKey = "com.vibe.wallet.mnemonic.backup"
    private static let addressDefaultsKey = "wallet.address"
    private static let pendingAddressDefaultsKey = "wallet.pending.address"

    static func saveKeystoreJSON(_ json: String) throws {
        try save(json, account: accountKey)
    }

    static func loadKeystoreJSON() -> String? {
        load(account: accountKey)
    }

    static func deleteKeystore() {
        delete(account: accountKey)
        delete(account: pendingKeystoreKey)
        delete(account: mnemonicKey)
        clearAddressDefaults()
    }

    /// 啟動時整理：勿誤刪 Keychain；僅在確認無任何 keystore 時清除 UserDefaults 殘留地址
    static func reconcileWalletStorage() {
        migrateLegacyKeystoreIfNeeded()

        if loadKeystoreJSON() != nil {
            // 已完成備份：清掉可能殘留的 pending
            delete(account: pendingKeystoreKey)
            UserDefaults.standard.removeObject(forKey: pendingAddressDefaultsKey)
            return
        }

        if loadPendingKeystoreJSON() != nil {
            // 建立到一半（備份步驟），保留 pending 供恢復
            return
        }

        clearAddressDefaults()
    }

    /// 舊版未綁定 kSecAttrService 的項目：僅遷移一次，絕不可在每次啟動刪除帶 service 的現有 keystore
    private static func migrateLegacyKeystoreIfNeeded() {
        let flag = "com.vibe.wallet.keychain.legacyMigrated"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }

        if loadKeystoreJSON() == nil, let legacy = loadLegacyWithoutService(account: accountKey) {
            try? save(legacy, account: accountKey)
        }
        UserDefaults.standard.set(true, forKey: flag)
    }

    /// 完全移除本機錢包（設定頁「移除錢包」）
    static func wipeAllWalletData() {
        delete(account: accountKey)
        delete(account: pendingKeystoreKey)
        delete(account: mnemonicKey)
        clearAddressDefaults()
    }

    private static func clearAddressDefaults() {
        UserDefaults.standard.removeObject(forKey: addressDefaultsKey)
        UserDefaults.standard.removeObject(forKey: pendingAddressDefaultsKey)
    }

    /// 建立錢包後、備份助記詞前暫存（避免大段 JSON 常駐 @State 導致真機記憶體壓力）
    static func savePendingKeystoreJSON(_ json: String) throws {
        try save(json, account: pendingKeystoreKey)
    }

    static func loadPendingKeystoreJSON() -> String? {
        load(account: pendingKeystoreKey)
    }

    static func clearPendingKeystore() {
        delete(account: pendingKeystoreKey)
    }

    static func savePendingAddress(_ address: String) {
        UserDefaults.standard.set(address, forKey: pendingAddressDefaultsKey)
    }

    static func loadPendingAddress() -> String? {
        UserDefaults.standard.string(forKey: pendingAddressDefaultsKey)
    }

    static func clearPendingWalletDraft() {
        clearPendingKeystore()
        UserDefaults.standard.removeObject(forKey: pendingAddressDefaultsKey)
    }

    // MARK: - 安全設定（交易 PIN 等）

    static func saveSecurityItem(_ value: String, account: String) throws {
        try save(value, account: account)
    }

    static func loadSecurityItem(account: String) -> String? {
        load(account: account)
    }

    static func deleteSecurityItem(account: String) {
        delete(account: account)
    }

    static func saveAddress(_ address: String) {
        UserDefaults.standard.set(address, forKey: addressDefaultsKey)
    }

    static func loadAddress() -> String? {
        UserDefaults.standard.string(forKey: addressDefaultsKey)
    }

    private static func save(_ value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: false,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw WalletError.keychainFailed
        }
    }

    private static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func loadLegacyWithoutService(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
}

enum WalletError: LocalizedError {
    case invalidMnemonic
    case derivationFailed
    case keychainFailed
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .invalidMnemonic: return "助記詞格式不正確，請檢查單字數量與拼寫。"
        case .derivationFailed: return "無法從助記詞衍生 Ethereum 地址。"
        case .keychainFailed: return "無法寫入系統鑰匙圈。"
        case .notConfigured: return "尚未建立或匯入錢包。"
        }
    }
}
