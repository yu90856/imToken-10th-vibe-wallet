import SwiftUI

/// 鏈上交易前驗證錢包密碼（Keystore 解鎖，非 4 碼交易 PIN）
struct WalletPasswordSheet: View {
    var onUnlocked: () -> Void
    var onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isVerifying = false
    @State private var isBiometryUnlocking = false

    private var canOfferBiometry: Bool {
        WalletBiometricUnlock.canUseWalletBiometry && WalletBiometricUnlock.hasStoredSigningPassword
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("輸入錢包密碼")
                    .notebookTitle(22)
                Text("鏈上簽名需使用建立／匯入錢包時設定的至少 8 碼密碼（與設定中的 4 碼交易 PIN 不同）。")
                    .notebookBody(14)
                    .foregroundStyle(AppTheme.ink.opacity(0.65))

                SecureField("錢包密碼", text: $password)
                    .font(NotebookFont.body(16))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppTheme.stickyNoteFill(for: colorScheme))
                    )

                if let errorMessage {
                    Text(errorMessage)
                        .notebookCaption(12)
                        .foregroundStyle(AppTheme.negative)
                }

                if canOfferBiometry {
                    Button(action: unlockWithBiometry) {
                        HStack(spacing: 8) {
                            if isBiometryUnlocking {
                                ProgressView()
                            }
                            Image(systemName: "faceid")
                            Text(isBiometryUnlocking ? "驗證中…" : "使用 \(TransactionAuthService.biometryTypeName) 解鎖")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(AppTheme.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(AppTheme.primary.opacity(0.45), lineWidth: 1.5)
                        )
                    }
                    .disabled(isVerifying || isBiometryUnlocking)
                }

                Button(action: verify) {
                    HStack {
                        if isVerifying { ProgressView().tint(.white) }
                        Text(isVerifying ? "驗證中…" : "確認並簽名")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.heroGradient))
                }
                .disabled(password.isEmpty || isVerifying || isBiometryUnlocking)

                Spacer()
            }
            .padding(24)
            .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .vibePresentedScreen()
    }

    private func unlockWithBiometry() {
        isBiometryUnlocking = true
        errorMessage = nil
        Task { @MainActor in
            defer { isBiometryUnlocking = false }
            let ok = await WalletSession.shared.tryUnlockSigningWithBiometry(
                reason: "解鎖錢包以簽署交易"
            )
            if ok {
                onUnlocked()
                dismiss()
            } else {
                errorMessage = "生物辨識解鎖失敗，請輸入錢包密碼。"
            }
        }
    }

    private func verify() {
        isVerifying = true
        errorMessage = nil
        Task { @MainActor in
            defer { isVerifying = false }
            do {
                guard let keystore = WalletKeychainStore.loadKeystoreJSON() else {
                    errorMessage = "找不到 Keystore"
                    return
                }
                let derived = try await TokenCoreService.verifyPassword(keystoreJSON: keystore, password: password)
                WalletSession.shared.applyVerifiedSigningAddress(derived)
                WalletSession.shared.unlockForSigning(password: password)
                WalletBiometricUnlock.persistSigningPasswordIfEnabled(password)
                onUnlocked()
                dismiss()
            } catch let error as WalletError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = "密碼錯誤或無法解鎖 Keystore"
            }
        }
    }
}
