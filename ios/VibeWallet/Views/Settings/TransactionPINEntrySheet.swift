import SwiftUI

struct TransactionPINEntrySheet: View {
    enum Mode {
        case verify
        case create
        case change
    }

    let mode: Mode
    var onComplete: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(titleText)
                    .notebookTitle(24)
                    .foregroundStyle(AppTheme.ink)

                Text(subtitleText)
                    .notebookBody(15)
                    .foregroundStyle(AppTheme.ink.opacity(0.65))

                pinField(title: fieldTitle, text: $pin)

                if mode != .verify {
                    pinField(title: "再次輸入", text: $confirmPin)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .notebookCaption(12)
                        .foregroundStyle(AppTheme.negative)
                }

                Button(action: submit) {
                    Text(primaryButtonTitle)
                        .notebookHeadline(18)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.heroGradient)
                        )
                }
                .disabled(pin.count < 4 || (mode != .verify && confirmPin.count < 4))

                Spacer()
            }
            .padding(24)
            .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        onComplete(false)
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var titleText: String {
        switch mode {
        case .verify: return "輸入交易密碼"
        case .create: return "設定交易密碼"
        case .change: return "變更交易密碼"
        }
    }

    private var subtitleText: String {
        switch mode {
        case .verify: return "交換與簽名操作需要 4 碼密碼確認。"
        case .create, .change: return "僅儲存於本機鑰匙圈，不會上傳。"
        }
    }

    private var fieldTitle: String {
        mode == .verify ? "4 碼密碼" : "新密碼"
    }

    private var primaryButtonTitle: String {
        mode == .verify ? "確認" : "儲存"
    }

    private func pinField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .notebookCaption(12)
                .foregroundStyle(AppTheme.ink.opacity(0.6))
            SecureField("••••", text: text)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(NotebookFont.title(28))
                .multilineTextAlignment(.center)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.stickyNoteFill(for: colorScheme))
                )
                .onChange(of: text.wrappedValue) { _, newValue in
                    let filtered = String(newValue.filter(\.isNumber).prefix(4))
                    if filtered != newValue { text.wrappedValue = filtered }
                }
        }
    }

    private func submit() {
        errorMessage = nil
        switch mode {
        case .verify:
            if SecuritySettingsStore.shared.verifyTransactionPIN(pin) {
                onComplete(true)
                dismiss()
            } else {
                errorMessage = "密碼不正確"
                pin = ""
            }
        case .create, .change:
            guard pin == confirmPin else {
                errorMessage = "兩次輸入不一致"
                return
            }
            do {
                try SecuritySettingsStore.shared.saveTransactionPIN(pin)
                onComplete(true)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
