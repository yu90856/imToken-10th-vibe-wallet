import CryptoKit
import Foundation
import LocalAuthentication
import Security

enum WalletKeychainStore {
    private static let service = "com.vibe.wallet.keychain"
    private static let accountKey = "com.vibe.wallet.keystore"
    private static let pendingKeystoreKey = "com.vibe.wallet.keystore.pending"
    private static let mnemonicKey = "com.vibe.wallet.mnemonic.backup"
    private static let walletPasswordVerifierKey = "com.vibe.wallet.password.verifier"
    private static let signingPasswordBiometricKey = "com.vibe.wallet.signingPassword.biometric"
    private static let addressDefaultsKey = "wallet.address"
    private static let canonicalAddressKey = "com.vibe.wallet.address.canonical"
    private static let pendingAddressDefaultsKey = "wallet.pending.address"
    /// 隨 App 刪除而清除；用於辨識「新安裝」並清掉 Keychain 殘留 keystore
    private static let installInstanceKey = "com.vibe.wallet.installInstanceId"

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
        delete(account: canonicalAddressKey)
        deleteWalletPasswordVerifier()
        deleteSigningPasswordForBiometry()
        clearAddressDefaults()
    }

    /// 啟動時整理：勿誤刪 Keychain；僅在確認無任何 keystore 時清除 UserDefaults 殘留地址
    static func reconcileWalletStorage() {
        reconcileFreshInstallKeychain()

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

    /// iOS 刪 App 後 Keychain 常仍保留；UserDefaults 清空代表新安裝，應回到建立／匯入流程
    private static func reconcileFreshInstallKeychain() {
        if UserDefaults.standard.string(forKey: installInstanceKey) != nil {
            return
        }
        UserDefaults.standard.set(UUID().uuidString, forKey: installInstanceKey)
        guard loadKeystoreJSON() != nil || loadPendingKeystoreJSON() != nil else { return }
        wipeAllWalletData()
    }

    /// 無需密碼即可從私鑰 keystore 還原地址（避免與 UserDefaults 快取地址不一致）
    static func addressFromKeystoreIfAvailable() -> String? {
        guard let keystore = loadKeystoreJSON(),
              ExternalPrivateKeyService.isExternalPrivateKeyKeystore(keystore),
              let hex = ExternalPrivateKeyService.privateKeyHex(from: keystore),
              let address = try? ExternalPrivateKeyService.ethereumAddress(fromPrivateKeyHex: hex) else {
            return nil
        }
        return address
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
        delete(account: canonicalAddressKey)
        deleteWalletPasswordVerifier()
        deleteSigningPasswordForBiometry()
        clearAddressDefaults()
    }

    // MARK: - 簽名密碼（Face ID / Touch ID 保護）

    static func hasBiometricSigningPassword() -> Bool {
        keychainItemExists(account: signingPasswordBiometricKey)
    }

    static func saveSigningPasswordForBiometry(_ password: String) throws {
        guard let data = password.data(using: .utf8) else { return }
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            throw WalletError.keychainFailed
        }
        deleteSigningPasswordForBiometry()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: signingPasswordBiometricKey,
            kSecAttrAccessControl as String: access,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw WalletError.keychainFailed
        }
    }

    static func loadSigningPasswordForBiometry(context: LAContext) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: signingPasswordBiometricKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
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

    static func deleteSigningPasswordForBiometry() {
        delete(account: signingPasswordBiometricKey)
    }

    private static func keychainItemExists(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    // MARK: - 私鑰錢包密碼驗證（tcx 不支援 externalPrivateKey keystore）

    static func hasWalletPasswordVerifier() -> Bool {
        load(account: walletPasswordVerifierKey) != nil
    }

    static func saveWalletPasswordVerifier(_ password: String) throws {
        var salt = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, salt.count, &salt) == errSecSuccess else {
            throw WalletError.keychainFailed
        }
        let digest = SHA256.hash(data: Data(salt) + Data(password.utf8))
        let payload: [String: String] = [
            "salt": Data(salt).base64EncodedString(),
            "hash": Data(digest).base64EncodedString(),
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: json, encoding: .utf8) else {
            throw WalletError.keychainFailed
        }
        try save(jsonString, account: walletPasswordVerifierKey)
    }

    static func verifyWalletPassword(_ password: String) -> Bool {
        guard let raw = load(account: walletPasswordVerifierKey),
              let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let saltB64 = json["salt"],
              let hashB64 = json["hash"],
              let salt = Data(base64Encoded: saltB64),
              let expected = Data(base64Encoded: hashB64) else {
            return false
        }
        let digest = SHA256.hash(data: salt + Data(password.utf8))
        return Data(digest) == expected
    }

    static func deleteWalletPasswordVerifier() {
        delete(account: walletPasswordVerifierKey)
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
        let normalized = address.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(normalized, forKey: addressDefaultsKey)
        try? saveCanonicalAddress(normalized)
    }

    static func loadAddress() -> String? {
        UserDefaults.standard.string(forKey: addressDefaultsKey)
    }

    /// 與 Keystore 一併寫入 Keychain，避免僅 UserDefaults 殘留舊地址（助記詞錢包無法無密碼從 keystore 還原地址）
    static func saveCanonicalAddress(_ address: String) throws {
        try save(address, account: canonicalAddressKey)
    }

    static func loadCanonicalAddress() -> String? {
        load(account: canonicalAddressKey)
    }

    /// 啟動還原顯示用：私鑰 keystore > Keychain 綁定地址 > UserDefaults
    static func resolvedDisplayAddress() -> String? {
        addressFromKeystoreIfAvailable()
            ?? loadCanonicalAddress()
            ?? loadAddress()
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
    case invalidPrivateKey
    case invalidPassword
    case derivationFailed
    case signingFailed
    case signingFailedWithDetail(String)
    case keychainFailed
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .invalidMnemonic: return "助記詞格式不正確，請檢查單字數量與拼寫。"
        case .invalidPrivateKey: return "私鑰格式不正確，需為 64 位十六進制字元（可含 0x 前綴）。"
        case .invalidPassword: return "錢包密碼不正確，請輸入建立／匯入錢包時設定的至少 8 碼密碼（非 4 碼交易 PIN）。"
        case .derivationFailed: return "無法從助記詞衍生 Ethereum 地址。"
        case .signingFailed: return "交易簽名失敗，請確認私鑰與網路設定。"
        case .signingFailedWithDetail(let detail): return "交易簽名失敗：\(detail)"
        case .keychainFailed: return "無法寫入系統鑰匙圈。"
        case .notConfigured: return "尚未建立或匯入錢包。"
        }
    }
}
