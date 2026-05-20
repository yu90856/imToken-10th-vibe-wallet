import Foundation
import Observation

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
            if faceIDEnabled, UserDefaults.standard.object(forKey: Key.duress) == nil {
                duressProtectionEnabled = true
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

    private init() {
        faceIDEnabled = UserDefaults.standard.bool(forKey: Key.faceID)
        useFaceIDForTransactions = UserDefaults.standard.bool(forKey: Key.faceIDForTx)
        if UserDefaults.standard.object(forKey: Key.duress) != nil {
            duressProtectionEnabled = UserDefaults.standard.bool(forKey: Key.duress)
        } else {
            duressProtectionEnabled = true
        }
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
