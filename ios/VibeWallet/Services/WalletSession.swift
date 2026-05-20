import Foundation
import Observation

@Observable
final class WalletSession {
    static let shared = WalletSession()

    private(set) var account: WalletAccount?
    private(set) var isUnlocked = false
    private(set) var unlockPassword: String?
    private(set) var isTokenCoreReady = false
    /// 須為儲存屬性，Keychain 寫入後 SwiftUI 才會切換到主畫面
    private(set) var hasWallet = false

    var displayAddress: String {
        account?.shortAddress ?? "未連接"
    }

    private init() {
        WalletKeychainStore.reconcileWalletStorage()
        refreshFromStorage()
    }

    /// App 回到前景或啟動時，從 Keychain 還原錢包狀態
    func refreshFromStorage() {
        syncHasWalletFromStorage()
        restoreCachedAccount()
    }

    private func syncHasWalletFromStorage() {
        // 僅以 Keychain keystore 為準；勿單靠 UserDefaults 地址（刪 App 後可能被 iCloud 還原）
        hasWallet = WalletKeychainStore.loadKeystoreJSON() != nil
    }

    /// App 啟動時預載 Token Core WASM
    @MainActor
    func warmUpTokenCore() async {
        do {
            try await TokenCoreBridge.shared.ensureReady()
            isTokenCoreReady = true
        } catch {
            isTokenCoreReady = false
            #if DEBUG
            print("[TokenCore] warmup failed:", error.localizedDescription)
            #endif
        }
    }

    func restoreCachedAccount() {
        syncHasWalletFromStorage()
        guard let address = WalletKeychainStore.loadAddress() else {
            account = nil
            return
        }
        account = WalletAccount(
            address: address,
            chainId: ChainConfig.active.id,
            createdAt: Date(),
            label: "ETH 主帳戶"
        )
        isUnlocked = true
    }

    @MainActor
    func createWallet(walletPassword: String) async throws -> (mnemonic: String, account: WalletAccount) {
        let result = try await TokenCoreService.createWallet(password: walletPassword)
        try persistWallet(
            keystoreJSON: result.keystoreJSON,
            address: result.address,
            password: walletPassword
        )
        guard let account else { throw WalletError.notConfigured }
        return (result.mnemonic, account)
    }

    @MainActor
    func importWallet(mnemonic: String, walletPassword: String) async throws -> (mnemonic: String, account: WalletAccount) {
        let normalized = TokenCoreService.normalizeMnemonic(mnemonic)
        guard await TokenCoreService.isValidMnemonic(normalized, password: walletPassword) else {
            throw WalletError.invalidMnemonic
        }
        let result = try await TokenCoreService.importWallet(mnemonic: normalized, password: walletPassword)
        try persistWallet(
            keystoreJSON: result.keystoreJSON,
            address: result.address,
            password: walletPassword
        )
        guard let account else { throw WalletError.notConfigured }
        return (normalized, account)
    }

    /// 建立流程：備份助記詞後寫入 Keychain
    @MainActor
    func finalizeCreatedWallet(keystoreJSON: String, address: String, password: String) throws {
        try persistWallet(keystoreJSON: keystoreJSON, address: address, password: password)
    }

    @MainActor
    private func persistWallet(keystoreJSON: String, address: String, password: String) throws {
        try WalletKeychainStore.saveKeystoreJSON(keystoreJSON)
        WalletKeychainStore.saveAddress(address)
        account = WalletAccount(
            address: address,
            chainId: ChainConfig.active.id,
            createdAt: Date(),
            label: "ETH 主帳戶"
        )
        unlockPassword = password
        isUnlocked = true
        hasWallet = true
    }

    func lock() {
        isUnlocked = false
        unlockPassword = nil
    }

    func signOut() {
        WalletKeychainStore.wipeAllWalletData()
        account = nil
        isUnlocked = false
        unlockPassword = nil
        hasWallet = false
    }
}
