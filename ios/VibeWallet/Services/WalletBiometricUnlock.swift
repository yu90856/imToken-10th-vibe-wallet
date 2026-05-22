import Foundation
import LocalAuthentication

/// 以 Face ID / Touch ID 解鎖已儲存於 Keychain 的錢包密碼（供鏈上簽名）
enum WalletBiometricUnlock {
    @MainActor
    static var canUseWalletBiometry: Bool {
        SecuritySettingsStore.shared.faceIDEnabled && TransactionAuthService.canUseBiometry
    }

    static var hasStoredSigningPassword: Bool {
        WalletKeychainStore.hasBiometricSigningPassword()
    }

    @MainActor
    static func persistSigningPasswordIfEnabled(_ password: String) {
        guard canUseWalletBiometry else { return }
        try? WalletKeychainStore.saveSigningPasswordForBiometry(password)
    }

    static func deleteStoredSigningPassword() {
        WalletKeychainStore.deleteSigningPasswordForBiometry()
    }

    /// 驗證生物辨識並解鎖 `WalletSession` 簽名密碼；成功回傳 true
    @MainActor
    static func tryUnlockSigningSession(reason: String) async -> Bool {
        guard canUseWalletBiometry, hasStoredSigningPassword else { return false }
        guard let keystore = WalletKeychainStore.loadKeystoreJSON() else { return false }

        do {
            let password = try await loadWalletPassword(reason: reason)
            let derived = try await TokenCoreService.verifyPassword(keystoreJSON: keystore, password: password)
            WalletSession.shared.applyVerifiedSigningAddress(derived)
            WalletSession.shared.unlockForSigning(password: password)
            return true
        } catch {
            #if DEBUG
            print("[WalletBiometricUnlock]", error.localizedDescription)
            #endif
            return false
        }
    }

    @MainActor
    private static func loadWalletPassword(reason: String) async throws -> String {
        let context = LAContext()
        context.localizedCancelTitle = "取消"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw TransactionAuthError.biometryUnavailable
        }

        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            if !ok { throw TransactionAuthError.cancelled }
        } catch let laError as LAError where laError.code == .userCancel || laError.code == .appCancel {
            throw TransactionAuthError.cancelled
        }

        guard let password = try WalletKeychainStore.loadSigningPasswordForBiometry(context: context) else {
            throw TransactionAuthError.failed("無法讀取已儲存的錢包密碼，請改用手動輸入。")
        }
        return password
    }
}
