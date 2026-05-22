import Foundation
import Observation

@MainActor
@Observable
final class WalletSession {
    static let shared = WalletSession()

    private(set) var account: WalletAccount?
    private(set) var isUnlocked = false
    private(set) var unlockPassword: String?
    private(set) var isTokenCoreReady = false
    /// 須為儲存屬性，Keychain 寫入後 SwiftUI 才會切換到主畫面
    private(set) var hasWallet = false
    /// 建立／匯入成功後提示開啟 Google Sepolia 水龍頭
    var shouldPromptGoogleSepoliaFaucet = false

    var displayAddress: String {
        account?.shortAddress ?? "未連接"
    }

    nonisolated private init() {}

    /// App 啟動後於主線程呼叫一次（`RootView` / `VibeWalletApp`）
    func bootstrapIfNeeded() {
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
        guard hasWallet else {
            account = nil
            return
        }

        guard let resolved = WalletKeychainStore.resolvedDisplayAddress(),
              !resolved.isEmpty else {
            account = nil
            return
        }
        let stored = WalletKeychainStore.loadAddress()
        if stored?.lowercased() != resolved.lowercased() {
            WalletKeychainStore.saveAddress(resolved)
        }
        account = WalletAccount(
            address: resolved,
            chainId: ChainConfig.active.id,
            createdAt: Date(),
            label: "ETH 主帳戶"
        )
        isUnlocked = true
    }

    /// 解鎖／簽名後與 Keystore 推導地址對齊（避免 UI 餘額與鏈上簽名地址不一致）
    func applyVerifiedSigningAddress(_ address: String) {
        let normalized = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.hasPrefix("0x"), normalized.count == 42 else { return }
        WalletKeychainStore.saveAddress(normalized)
        if account?.address.lowercased() != normalized.lowercased() {
            account = WalletAccount(
                address: normalized,
                chainId: ChainConfig.active.id,
                createdAt: account?.createdAt ?? Date(),
                label: account?.label ?? "ETH 主帳戶"
            )
            NotificationCenter.default.post(name: .walletBalancesDidChange, object: nil)
        }
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
    func importPrivateKey(_ privateKey: String, walletPassword: String) async throws -> WalletAccount {
        guard let normalized = ExternalPrivateKeyService.normalizePrivateKey(privateKey) else {
            throw WalletError.invalidPrivateKey
        }
        let address = try ExternalPrivateKeyService.ethereumAddress(fromPrivateKeyHex: normalized)
        let keystoreJSON = ExternalPrivateKeyService.externalPrivateKeyKeystore(privateKeyHex: normalized)
        try persistWallet(
            keystoreJSON: keystoreJSON,
            address: address,
            password: walletPassword
        )
        guard let account else { throw WalletError.notConfigured }
        return account
    }

    @MainActor
    func importWallet(mnemonic: String, walletPassword: String) async throws -> (mnemonic: String, account: WalletAccount) {
        let normalized = TokenCoreService.normalizeMnemonic(mnemonic)
        guard await TokenCoreService.isValidMnemonic(normalized, password: walletPassword) else {
            throw WalletError.invalidMnemonic
        }
        WalletKeychainStore.wipeAllWalletData()
        let result = try await TokenCoreService.importWallet(mnemonic: normalized, password: walletPassword)
        let verifiedAddress = try await TokenCoreService.deriveEthereumAddress(
            keystoreJSON: result.keystoreJSON,
            password: walletPassword
        )
        try persistWallet(
            keystoreJSON: result.keystoreJSON,
            address: verifiedAddress,
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
        if ExternalPrivateKeyService.isExternalPrivateKeyKeystore(keystoreJSON) {
            try? WalletKeychainStore.saveWalletPasswordVerifier(password)
        }
        if ChainConfig.usesTestnet {
            shouldPromptGoogleSepoliaFaucet = true
        }
    }

    func clearGoogleSepoliaFaucetPrompt() {
        shouldPromptGoogleSepoliaFaucet = false
    }

    func lock() {
        isUnlocked = false
        unlockPassword = nil
    }

    /// 鏈上簽名用（驗證錢包密碼後暫存於記憶體，App 結束或 lock 時清除）
    func unlockForSigning(password: String) {
        unlockPassword = password
        isUnlocked = true
        WalletBiometricUnlock.persistSigningPasswordIfEnabled(password)
    }

    /// 優先以 Face ID 解鎖簽名密碼（已儲存於 Keychain 時）
    @MainActor
    func tryUnlockSigningWithBiometry(reason: String) async -> Bool {
        await WalletBiometricUnlock.tryUnlockSigningSession(reason: reason)
    }

    var signingPassword: String? {
        unlockPassword
    }

    func signOut() {
        let previousAddress = account?.address
        WalletBalanceStore.shared.clear()
        WalletKeychainStore.wipeAllWalletData()
        if let previousAddress {
            PufferDemoLedger.reset(address: previousAddress)
        }
        account = nil
        isUnlocked = false
        unlockPassword = nil
        hasWallet = false
        shouldPromptGoogleSepoliaFaucet = false
    }
}
