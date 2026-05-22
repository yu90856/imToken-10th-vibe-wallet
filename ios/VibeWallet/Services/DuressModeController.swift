import Foundation
import Observation

/// 脅迫防護：解鎖後先進入假錢包；依序點 Deck「交換→交換→錢包→錢包」退出
@MainActor
@Observable
final class DuressModeController {
    static let shared = DuressModeController()

    private let unlockSequence: [AppTab] = [.swap, .swap, .wallet, .wallet]
    private var tapSequence: [AppTab] = []
    private var cooldownTask: Task<Void, Never>?

    static let fakeErrorCooldownSeconds = 5

    /// App 進入前景時需 Face ID
    private(set) var isAppLocked = false
    /// 僅在進入背景後才需重新解鎖（避免 Face ID 系統 UI 觸發 inactive→active 循環上鎖）
    private var needsUnlockAfterBackground = true
    /// 顯示假錢包（餘額 0、假地址與假交易）
    private(set) var isDecoyActive = false
    /// 假錢包內敏感操作觸發的偽錯誤遮罩
    private(set) var fakeErrorPresented = false
    private(set) var fakeErrorSecondsLeft = 0

    nonisolated private init() {}

    /// 僅「設定 → Face ID」決定是否前景上鎖；脅迫防護只影響解鎖後是否進假錢包
    var shouldLockOnForeground: Bool {
        SecuritySettingsStore.shared.faceIDEnabled
            && WalletSession.shared.hasWallet
    }

    private var isLockBypassed: Bool {
        ContactRecoveryStore.shared.isInGracePeriod
    }

    func lockForForeground() {
        guard shouldLockOnForeground, needsUnlockAfterBackground, !isLockBypassed else { return }
        isAppLocked = true
        tapSequence = []
    }

    /// App 進入背景時標記，下次回前景才上鎖
    func markNeedsUnlockAfterBackground() {
        guard shouldLockOnForeground, !isLockBypassed else { return }
        needsUnlockAfterBackground = true
    }

    @MainActor
    func unlockViaContactRecovery() {
        ContactRecoveryStore.shared.grantGracePeriod()
        unlockSucceeded()
    }

    @MainActor
    func unlockSucceeded() {
        isAppLocked = false
        needsUnlockAfterBackground = false
        if SecuritySettingsStore.shared.duressProtectionEnabled {
            isDecoyActive = true
        } else {
            isDecoyActive = false
        }
        tapSequence = []
        dismissFakeError()
    }

    func registerDeckTap(_ tab: AppTab) {
        guard isDecoyActive else { return }
        tapSequence.append(tab)
        if tapSequence.count > unlockSequence.count {
            tapSequence.removeFirst()
        }
        if tapSequence == unlockSequence {
            isDecoyActive = false
            tapSequence = []
            Task { @MainActor in dismissFakeError() }
        }
    }

    func cancelDecoy() {
        isDecoyActive = false
        tapSequence = []
        Task { @MainActor in dismissFakeError() }
    }

    // MARK: - 假錢包敏感操作 → 偽系統錯誤

    /// 假錢包模式下之提幣／交換／簽名等（顯示錯誤並倒數 5 秒）
    @MainActor
    func recordHostileAction() {
        guard isDecoyActive else { return }
        presentFakeError()
    }

    @MainActor
    func presentFakeError() {
        fakeErrorPresented = true
        startFakeErrorCountdown()
    }

    @MainActor
    func confirmFakeErrorTapped() {
        if fakeErrorSecondsLeft > 0 {
            startFakeErrorCountdown()
        } else {
            dismissFakeError()
        }
    }

    @MainActor
    private func startFakeErrorCountdown() {
        cooldownTask?.cancel()
        fakeErrorSecondsLeft = Self.fakeErrorCooldownSeconds

        cooldownTask = Task { @MainActor in
            for remaining in stride(from: Self.fakeErrorCooldownSeconds, through: 1, by: -1) {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                fakeErrorSecondsLeft = remaining - 1
            }
            fakeErrorSecondsLeft = 0
            fakeErrorPresented = false
        }
    }

    @MainActor
    private func dismissFakeError() {
        cooldownTask?.cancel()
        cooldownTask = nil
        fakeErrorPresented = false
        fakeErrorSecondsLeft = 0
    }
}
