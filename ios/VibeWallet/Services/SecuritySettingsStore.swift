import Foundation
import Observation

@MainActor
@Observable
final class SecuritySettingsStore {
    static let shared = SecuritySettingsStore()

    private enum Key {
        static let faceID = "security.faceIDEnabled"
        static let faceIDForTx = "security.useFaceIDForTransactions"
        static let duress = "security.duressProtectionEnabled"
        static let pinAccount = "com.vibe.wallet.txPin"
    }

    var faceIDEnabled: Bool {
        didSet {
            UserDefaults.standard.set(faceIDEnabled, forKey: Key.faceID)
            if !faceIDEnabled {
                useFaceIDForTransactions = false
                WalletBiometricUnlock.deleteStoredSigningPassword()
            }
        }
    }

    var duressProtectionEnabled: Bool {
        didSet { UserDefaults.standard.set(duressProtectionEnabled, forKey: Key.duress) }
    }

    var useFaceIDForTransactions: Bool {
        didSet { UserDefaults.standard.set(useFaceIDForTransactions, forKey: Key.faceIDForTx) }
    }

    var hasTransactionPIN: Bool {
        WalletKeychainStore.loadSecurityItem(account: Key.pinAccount) != nil
    }

    /// 可用 Face ID / Touch ID 解鎖錢包密碼與 App 鎖定
    var allowsBiometricUnlock: Bool {
        faceIDEnabled && TransactionAuthService.canUseBiometry
    }

    /// 交換／簽名確認可改用生物辨識（免輸入 4 碼 PIN）
    var allowsBiometricTransactionConfirmation: Bool {
        allowsBiometricUnlock && useFaceIDForTransactions
    }

    private init() {
        let defaults = UserDefaults.standard
        let resolvedFaceID: Bool
        if defaults.object(forKey: Key.faceID) == nil {
            resolvedFaceID = TransactionAuthService.canUseBiometry
        } else {
            resolvedFaceID = defaults.bool(forKey: Key.faceID)
        }
        let resolvedTxFaceID: Bool
        if defaults.object(forKey: Key.faceIDForTx) == nil {
            resolvedTxFaceID = resolvedFaceID
        } else {
            resolvedTxFaceID = defaults.bool(forKey: Key.faceIDForTx)
        }
        let resolvedDuress: Bool
        if defaults.object(forKey: Key.duress) != nil {
            resolvedDuress = defaults.bool(forKey: Key.duress)
        } else {
            resolvedDuress = false
        }
        faceIDEnabled = resolvedFaceID
        useFaceIDForTransactions = resolvedTxFaceID
        duressProtectionEnabled = resolvedDuress
    }

    func saveTransactionPIN(_ pin: String) throws {
        guard pin.count == 4, pin.allSatisfy(\.isNumber) else {
            throw SecuritySettingsError.invalidPIN
        }
        try WalletKeychainStore.saveSecurityItem(pin, account: Key.pinAccount)
    }

    func verifyTransactionPIN(_ pin: String) -> Bool {
        guard pin.count == 4 else { return false }
        return WalletKeychainStore.loadSecurityItem(account: Key.pinAccount) == pin
    }

    func clearTransactionPIN() {
        WalletKeychainStore.deleteSecurityItem(account: Key.pinAccount)
    }
}

enum SecuritySettingsError: LocalizedError {
    case invalidPIN
    case pinNotSet

    var errorDescription: String? {
        switch self {
        case .invalidPIN: return "請輸入 4 位數字交易密碼。"
        case .pinNotSet: return "請先在設定中建立 4 碼交易密碼。"
        }
    }
}
