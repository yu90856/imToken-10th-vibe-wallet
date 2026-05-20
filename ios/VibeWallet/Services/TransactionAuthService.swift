import Foundation
import LocalAuthentication

enum TransactionAuthError: LocalizedError {
    case pinNotSet
    case pinRequired
    case biometryUnavailable
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .pinNotSet: return "請先在設定中建立 4 碼交易密碼。"
        case .pinRequired: return "請輸入交易密碼。"
        case .biometryUnavailable: return TransactionAuthService.biometryUnavailableMessage
        case .cancelled: return "已取消驗證。"
        case .failed(let message): return message
        }
    }
}

enum TransactionAuthService {
    static var biometryTypeName: String {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "生物辨識"
        }
    }

    static var canUseBiometry: Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        return context.biometryType != .none
    }

    static var biometryUnavailableMessage: String {
        if let reason = laFailureMessage() { return reason }
        #if targetEnvironment(simulator)
        return "模擬器請在選單 Features → Face ID → Enrolled 啟用後，再開啟此選項。"
        #else
        return "此裝置無法使用生物辨識，請至「設定」→「Face ID 與密碼」完成設定。"
        #endif
    }

    static var setupHint: String? {
        canUseBiometry ? nil : biometryUnavailableMessage
    }

    private static func laFailureMessage() -> String? {
        let context = LAContext()
        var error: NSError?
        guard !context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return nil
        }
        guard let error else { return nil }
        guard let code = LAError.Code(rawValue: error.code) else {
            return error.localizedDescription
        }
        switch code {
        case .biometryNotEnrolled:
            return "尚未登記 \(biometryTypeName)。請至 iPhone「設定」→「Face ID 與密碼」完成設定。"
        case .biometryNotAvailable:
            return "此裝置不支援生物辨識。"
        case .biometryLockout:
            return "生物辨識已鎖定，請使用裝置密碼解鎖後再試。"
        case .passcodeNotSet:
            return "請先設定裝置密碼，才能使用 Face ID / Touch ID。"
        case .notInteractive:
            return "請稍後再試。"
        default:
            return error.localizedDescription
        }
    }

    /// 交換／簽名前驗證：優先 Face ID（若已開啟），否則要求 4 碼 PIN
    @MainActor
    static func authenticateForTransaction(reason: String) async throws {
        if DuressModeController.shared.isDecoyActive {
            await DuressModeController.shared.recordHostileAction()
        }

        let settings = SecuritySettingsStore.shared

        if settings.useFaceIDForTransactions && canUseBiometry {
            try await evaluateBiometry(reason: reason)
            return
        }

        guard settings.hasTransactionPIN else {
            throw TransactionAuthError.pinNotSet
        }
        throw TransactionAuthError.pinRequired
    }

    @MainActor
    static func evaluateBiometry(reason: String) async throws {
        guard canUseBiometry else { throw TransactionAuthError.biometryUnavailable }

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
        } catch let laError as LAError where laError.code == .biometryNotAvailable || laError.code == .biometryNotEnrolled {
            throw TransactionAuthError.biometryUnavailable
        } catch {
            if error is TransactionAuthError { throw error }
            throw TransactionAuthError.failed(error.localizedDescription)
        }
    }
}
