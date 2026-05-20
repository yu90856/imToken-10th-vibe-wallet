import SwiftUI

/// 從背景回到 App 時的 Face ID 全螢幕鎖定
struct AppLockOverlay: View {
    @Bindable var duress = DuressModeController.shared
    @Bindable private var recovery = ContactRecoveryStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var errorMessage: String?
    @State private var didAutoPromptThisLock = false
    @State private var showContactUnlock = false
    @State private var biometryFailed = false

    var body: some View {
        ZStack {
            AppTheme.pageBackground(for: colorScheme)
                .ignoresSafeArea()
            NotebookPaperBackground()
                .ignoresSafeArea()
                .opacity(0.6)

            VStack(spacing: 20) {
                SketchIcon(kind: .lock, size: 48, color: AppTheme.primary)
                Text("Vibe Wallet 已鎖定")
                    .notebookTitle(24)
                    .foregroundStyle(AppTheme.ink)
                Text("使用 \(TransactionAuthService.biometryTypeName) 解鎖")
                    .notebookBody(15)
                    .foregroundStyle(AppTheme.ink.opacity(0.6))

                if let errorMessage {
                    Text(errorMessage)
                        .notebookCaption(12)
                        .foregroundStyle(AppTheme.negative)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button(action: unlock) {
                    Text("解鎖")
                        .notebookHeadline(17)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.heroGradient)
                        )
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)

                if biometryFailed && recovery.isConfigured {
                    Button {
                        showContactUnlock = true
                    } label: {
                        Text("聯絡人解鎖")
                            .notebookHeadline(15)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(AppTheme.primary)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(AppTheme.primary, lineWidth: 1.5)
                            )
                    }
                    .padding(.horizontal, 40)

                    Text("輸入任意兩組正確提示詞")
                        .notebookCaption(11)
                        .foregroundStyle(AppTheme.ink.opacity(0.5))
                }
            }
        }
        .onAppear {
            guard !didAutoPromptThisLock else { return }
            didAutoPromptThisLock = true
            unlock()
        }
        .onChange(of: duress.isAppLocked) { _, locked in
            if locked {
                didAutoPromptThisLock = false
                biometryFailed = false
                errorMessage = nil
            }
        }
        .sheet(isPresented: $showContactUnlock) {
            ContactRecoveryUnlockSheet()
        }
    }

    private func unlock() {
        Task { @MainActor in
            guard duress.isAppLocked else { return }
            errorMessage = nil
            do {
                try await TransactionAuthService.evaluateBiometry(
                    reason: "解鎖 Vibe Wallet"
                )
                biometryFailed = false
                duress.unlockSucceeded()
            } catch {
                biometryFailed = true
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
