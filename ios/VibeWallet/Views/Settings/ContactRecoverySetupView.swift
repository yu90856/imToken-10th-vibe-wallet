import SwiftUI

struct ContactRecoverySetupView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable private var recovery = ContactRecoveryStore.shared

    @State private var hint1 = ""
    @State private var hint2 = ""
    @State private var hint3 = ""
    @State private var message: String?
    @State private var isError = false
    @State private var showClearConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                infoCard

                sectionTitle("三組提示詞")
                hintField("提示詞 1", text: $hint1)
                hintField("提示詞 2", text: $hint2)
                hintField("提示詞 3", text: $hint3)

                Button(action: save) {
                    Text("儲存提示詞")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.heroGradient)
                        )
                }

                if recovery.isConfigured {
                    Button("清除提示詞設定", role: .destructive) {
                        showClearConfirm = true
                    }
                    .frame(maxWidth: .infinity)
                }

                if let message {
                    Text(message)
                        .notebookCaption(12)
                        .foregroundStyle(isError ? AppTheme.negative : AppTheme.positive)
                }
            }
            .padding(20)
        }
        .walletDeckScrollInset()
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
        .navigationTitle("聯絡人解鎖")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            recovery.reloadFromKeychain()
        }
        .alert("清除設定？", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                recovery.disableAndClear()
                clearFields()
                message = "已清除提示詞"
                isError = false
            }
        } message: {
            Text("將刪除三組提示詞，Face ID 失敗時將無法使用此方式解鎖。")
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Face ID 失敗時的備用解鎖")
                .notebookHeadline(16)
            Text(
                "自訂三組提示詞（可為中文）。"
                + "解鎖時輸入其中任意兩組正確詞語；成功後 30 分鐘內 App 不會再上鎖。"
            )
            .notebookBody(13)
            .foregroundStyle(AppTheme.ink.opacity(0.65))
            if recovery.isConfigured {
                Text("已設定 \(recovery.hintCount) 組提示詞（不顯示已存內容）")
                    .notebookCaption(12)
                    .foregroundStyle(AppTheme.positive)
            }
            if let grace = recovery.gracePeriodRemainingText {
                Text(grace)
                    .notebookCaption(12)
                    .foregroundStyle(AppTheme.positive)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16, variant: .yellow)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .notebookCaption(12)
            .foregroundStyle(AppTheme.ink.opacity(0.5))
            .textCase(.uppercase)
    }

    private func hintField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .notebookCaption(12)
                .foregroundStyle(AppTheme.ink.opacity(0.55))
            TextField("可輸入中文", text: text)
                .autocorrectionDisabled()
                .padding(12)
                .background(fieldBackground)
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
    }

    private func save() {
        do {
            try recovery.save(hints: [hint1, hint2, hint3])
            message = "已儲存三組提示詞。"
            isError = false
            hint1 = ""
            hint2 = ""
            hint3 = ""
        } catch {
            message = error.localizedDescription
            isError = true
        }
    }

    private func clearFields() {
        hint1 = ""
        hint2 = ""
        hint3 = ""
    }
}

#Preview {
    NavigationStack {
        ContactRecoverySetupView()
    }
}
