import Foundation

enum BiometricProtectionState: String, Equatable {
    case active
    case inactive
    case unavailable

    var title: String {
        switch self {
        case .active: return "已啟用"
        case .inactive: return "未啟用"
        case .unavailable: return "不可用"
        }
    }

    var subtitle: String {
        switch self {
        case .active: return "Secure Enclave · Face ID"
        case .inactive: return "建議立即開啟生物辨識"
        case .unavailable: return "此裝置不支援 Secure Enclave"
        }
    }
}

enum BackupGuardianState: String, Equatable {
    case fullyProtected
    case partial
    case notConfigured

    var title: String {
        switch self {
        case .fullyProtected: return "守護完整"
        case .partial: return "部分守護"
        case .notConfigured: return "尚未設定"
        }
    }

    var subtitle: String {
        switch self {
        case .fullyProtected: return "3/3 備份守護者已就緒"
        case .partial: return "1/3 備份守護者 · 建議補齊"
        case .notConfigured: return "社交恢復尚未配置"
        }
    }
}

struct SovereigntyStatus: Equatable {
    let biometric: BiometricProtectionState
    let backupGuardian: BackupGuardianState
    let defenseScore: Int
    let lastVerified: Date

    var isDefenseOptimal: Bool {
        biometric == .active && backupGuardian == .fullyProtected
    }
}
