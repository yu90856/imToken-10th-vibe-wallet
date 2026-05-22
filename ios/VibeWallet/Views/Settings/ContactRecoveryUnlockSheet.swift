import SwiftUI

struct ContactRecoveryUnlockSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Bindable private var recovery = ContactRecoveryStore.shared
    @Bindable private var duress = DuressModeController.shared

    @State private var hint1 = ""
    @State private var hint2 = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("提示詞解鎖")
                            .notebookTitle(22)
                        Text("輸入您事先設定的任意兩組正確提示詞（支援中文）。")
                            .notebookBody(14)
                            .foregroundStyle(AppTheme.ink.opacity(0.65))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("提示詞 1")
                            .notebookCaption(12)
                            .foregroundStyle(AppTheme.ink.opacity(0.55))
                        TextField("第一組提示詞", text: $hint1)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(fieldBackground)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("提示詞 2")
                            .notebookCaption(12)
                            .foregroundStyle(AppTheme.ink.opacity(0.55))
                        TextField("第二組提示詞", text: $hint2)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(fieldBackground)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .notebookCaption(12)
                            .foregroundStyle(AppTheme.negative)
                    }

                    Button(action: attemptUnlock) {
                        Text("驗證並解鎖")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(AppTheme.heroGradient)
                            )
                    }
                    .disabled(hint1.trimmingCharacters(in: .whitespaces).isEmpty
                        || hint2.trimmingCharacters(in: .whitespaces).isEmpty)

                    Text("解鎖成功後 30 分鐘內不會再次鎖定 App。")
                        .notebookCaption(11)
                        .foregroundStyle(AppTheme.ink.opacity(0.5))
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .vibePresentedScreen()
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
    }

    private func attemptUnlock() {
        if recovery.verify(hint1: hint1, hint2: hint2) {
            duress.unlockViaContactRecovery()
            hint1 = ""
            hint2 = ""
            dismiss()
        } else {
            errorMessage = ContactRecoveryError.verificationFailed.errorDescription
        }
    }
}
