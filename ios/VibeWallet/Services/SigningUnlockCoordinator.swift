import Foundation

/// 鏈上簽名前的解鎖流程：已存錢包密碼時 **一次 Face ID** 完成交易確認＋解鎖。
@MainActor
enum SigningUnlockCoordinator {
    enum NextStep {
        case readyToSign
        case needWalletPassword
    }

    static func prepareForSigning(reason: String) async throws -> NextStep {
        let session = WalletSession.shared
        let settings = SecuritySettingsStore.shared

        if session.signingPassword != nil {
            return .readyToSign
        }

        if settings.allowsBiometricTransactionConfirmation,
           WalletBiometricUnlock.hasStoredSigningPassword {
            if await session.tryUnlockSigningWithBiometry(reason: reason) {
                return .readyToSign
            }
            throw TransactionAuthError.cancelled
        }

        try await TransactionAuthService.authenticateForTransaction(reason: reason)

        if session.signingPassword != nil {
            return .readyToSign
        }

        if settings.allowsBiometricUnlock, WalletBiometricUnlock.hasStoredSigningPassword {
            if await session.tryUnlockSigningWithBiometry(reason: reason) {
                return .readyToSign
            }
        }

        return .needWalletPassword
    }
}
