import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(WalletSession.self) private var walletSession
    @Bindable private var security = SecuritySettingsStore.shared
    @Bindable private var recovery = ContactRecoveryStore.shared

    @State private var showCreatePIN = false
    @State private var showChangePIN = false
    @State private var pinMessage: String?
    @State private var biometryHint: String?
    @State private var showBiometryAlert = false
    @State private var biometryAlertMessage = ""
    @State private var showRemoveWalletConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("設定")
                    .notebookTitle(28)
                    .foregroundStyle(AppTheme.ink)

                if walletSession.hasWallet {
                    walletSection
                }
                integrationCheckSection
                securitySection
                contactRecoverySection
                transactionSection
                sovereigntyNoteSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            biometryHint = TransactionAuthService.setupHint
        }
        .alert("無法啟用生物辨識", isPresented: $showBiometryAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(biometryAlertMessage)
        }
        .alert("移除本機錢包？", isPresented: $showRemoveWalletConfirm) {
            Button("取消", role: .cancel) {}
            Button("移除", role: .destructive) {
                walletSession.signOut()
            }
        } message: {
            Text("將刪除本機 keystore 與地址，需重新建立或匯入助記詞。請確認已備份助記詞。")
        }
        .sheet(isPresented: $showCreatePIN) {
            TransactionPINEntrySheet(mode: .create) { ok in
                if ok { pinMessage = "交易密碼已設定" }
            }
        }
        .sheet(isPresented: $showChangePIN) {
            TransactionPINEntrySheet(mode: .change) { ok in
                if ok { pinMessage = "交易密碼已更新" }
            }
        }
    }

    private var walletSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("錢包")

            VStack(alignment: .leading, spacing: 10) {
                if let account = walletSession.account {
                    Text(account.address)
                        .font(.caption.monospaced())
                        .foregroundStyle(AppTheme.ink.opacity(0.7))
                        .textSelection(.enabled)
                }
                Button(role: .destructive) {
                    showRemoveWalletConfirm = true
                } label: {
                    Text("移除本機錢包")
                        .notebookHeadline(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("刪除 App 後若仍直接進首頁，請用此按鈕或刪 App 後關閉 iCloud 備份還原再重裝。")
                    .notebookCaption(11)
                    .foregroundStyle(AppTheme.ink.opacity(0.55))
            }
            .padding(16)
            .glassCard(cornerRadius: 16, variant: .pink)
        }
    }

    private var integrationCheckSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("評審 · 功能檢測")

            NavigationLink {
                IntegrationCheckView()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("一鍵檢測 GitHub 整合")
                            .notebookHeadline(16)
                            .foregroundStyle(AppTheme.ink)
                        Text("Token Core、CoinGecko、DApp 瀏覽器、Sepolia 等")
                            .notebookCaption(12)
                            .foregroundStyle(AppTheme.ink.opacity(0.55))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.ink.opacity(0.35))
                }
                .padding(16)
            }
            .glassCard(cornerRadius: 16, variant: .mint)
        }
    }

    private var contactRecoverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("聯絡人解鎖")

            NavigationLink {
                ContactRecoverySetupView()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("設定三組提示詞")
                            .notebookHeadline(16)
                            .foregroundStyle(AppTheme.ink)
                        Text(contactRecoverySubtitle)
                            .notebookCaption(12)
                            .foregroundStyle(AppTheme.ink.opacity(0.55))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.ink.opacity(0.35))
                }
                .padding(16)
            }
            .glassCard(cornerRadius: 16, variant: .yellow)
        }
    }

    private var contactRecoverySubtitle: String {
        if let grace = recovery.gracePeriodRemainingText {
            return grace
        }
        if recovery.isConfigured {
            return "已設定 · Face ID 失敗可用 2/3 提示詞解鎖"
        }
        return "Face ID 失敗時輸入兩組提示詞（可中文）· 解鎖後 30 分鐘免鎖"
    }

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("安全與驗證")

            VStack(alignment: .leading, spacing: 0) {
                toggleRow(
                    title: "啟用 \(TransactionAuthService.biometryTypeName)",
                    subtitle: "開啟時會要求驗證一次；用於 App 鎖定與主畫面主權狀態",
                    isOn: faceIDBinding
                )

                if let biometryHint {
                    Text(biometryHint)
                        .notebookCaption(11)
                        .foregroundStyle(AppTheme.ink.opacity(0.55))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                Divider().opacity(0.35)
                    .padding(.horizontal, 16)

                toggleRow(
                    title: "脅迫防護（假錢包）",
                    subtitle: "解鎖後先顯示餘額 0 的假錢包；依序點 Deck「交換→交換→錢包→錢包」進入真實資產",
                    isOn: duressBinding
                )
            }
            .glassCard(cornerRadius: 16, variant: .yellow)
        }
    }

    private var transactionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("交易確認")

            VStack(alignment: .leading, spacing: 14) {
                toggleRow(
                    title: "交換／簽名使用 \(TransactionAuthService.biometryTypeName)",
                    subtitle: security.faceIDEnabled
                        ? "關閉時改以 4 碼交易密碼確認"
                        : "請先啟用上方生物辨識",
                    isOn: txFaceIDBinding
                )

                Divider().opacity(0.35)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("4 碼交易密碼")
                            .notebookHeadline(16)
                            .foregroundStyle(AppTheme.ink)
                        Text(security.hasTransactionPIN ? "已設定 · 本機鑰匙圈" : "尚未設定")
                            .notebookCaption(12)
                            .foregroundStyle(AppTheme.ink.opacity(0.55))
                    }
                    Spacer()
                    if security.hasTransactionPIN {
                        Button("變更") { showChangePIN = true }
                            .font(NotebookFont.body(14))
                            .foregroundStyle(AppTheme.primary)
                    } else {
                        Button("設定") { showCreatePIN = true }
                            .font(NotebookFont.body(14).weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                    }
                }

                if let pinMessage {
                    Text(pinMessage)
                        .notebookCaption(12)
                        .foregroundStyle(AppTheme.positive)
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16, variant: .pink)
        }
    }

    private var sovereigntyNoteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("主權架構（評審說明）")

            VStack(alignment: .leading, spacing: 10) {
                Text("Passkey（控制權）+ ERC-4337 智能合約（資產載體）")
                    .notebookHeadline(15)
                    .foregroundStyle(AppTheme.ink)

                Text(
                    "以太坊 EOA 不支援 Passkey（secp256k1 vs secp256r1）。"
                    + "資產置於鏈上帳戶抽象合約，僅在 Passkey 驗證通過後可動用。"
                    + "流程：規劃交易 → Face ID → Secure Enclave 簽名 → 鏈上驗證 → 執行。"
                )
                .notebookBody(13)
                .foregroundStyle(AppTheme.ink.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .glassCard(cornerRadius: 16, variant: .yellow, tilt: -0.8)
        }
    }

    private var faceIDBinding: Binding<Bool> {
        Binding(
            get: { security.faceIDEnabled },
            set: { newValue in
                if newValue {
                    Task { @MainActor in await requestEnableFaceID() }
                } else {
                    security.faceIDEnabled = false
                    security.useFaceIDForTransactions = false
                    biometryHint = TransactionAuthService.setupHint
                }
            }
        )
    }

    private var txFaceIDBinding: Binding<Bool> {
        Binding(
            get: { security.useFaceIDForTransactions },
            set: { newValue in
                if newValue {
                    Task { @MainActor in await requestEnableTxFaceID() }
                } else {
                    security.useFaceIDForTransactions = false
                }
            }
        )
    }

    private var duressBinding: Binding<Bool> {
        Binding(
            get: { security.duressProtectionEnabled },
            set: { newValue in
                if newValue, !security.faceIDEnabled {
                    biometryAlertMessage = "請先啟用 \(TransactionAuthService.biometryTypeName)。"
                    showBiometryAlert = true
                    return
                }
                security.duressProtectionEnabled = newValue
            }
        )
    }

    @MainActor
    private func requestEnableFaceID() async {
        guard TransactionAuthService.canUseBiometry else {
            security.faceIDEnabled = false
            biometryAlertMessage = TransactionAuthService.biometryUnavailableMessage
            showBiometryAlert = true
            biometryHint = TransactionAuthService.setupHint
            return
        }

        do {
            try await TransactionAuthService.evaluateBiometry(
                reason: "驗證以啟用 \(TransactionAuthService.biometryTypeName)"
            )
            security.faceIDEnabled = true
            biometryHint = nil
        } catch {
            security.faceIDEnabled = false
            if let error = error as? LocalizedError, let msg = error.errorDescription {
                biometryAlertMessage = msg
            } else {
                biometryAlertMessage = error.localizedDescription
            }
            showBiometryAlert = true
        }
    }

    @MainActor
    private func requestEnableTxFaceID() async {
        guard security.faceIDEnabled else {
            security.useFaceIDForTransactions = false
            biometryAlertMessage = "請先啟用 \(TransactionAuthService.biometryTypeName)。"
            showBiometryAlert = true
            return
        }

        guard TransactionAuthService.canUseBiometry else {
            security.useFaceIDForTransactions = false
            biometryAlertMessage = TransactionAuthService.biometryUnavailableMessage
            showBiometryAlert = true
            return
        }

        do {
            try await TransactionAuthService.evaluateBiometry(
                reason: "驗證以用於交換／簽名確認"
            )
            security.useFaceIDForTransactions = true
        } catch {
            security.useFaceIDForTransactions = false
            if let error = error as? LocalizedError, let msg = error.errorDescription {
                biometryAlertMessage = msg
            } else {
                biometryAlertMessage = error.localizedDescription
            }
            showBiometryAlert = true
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .notebookCaption(12)
            .foregroundStyle(AppTheme.ink.opacity(0.5))
            .textCase(.uppercase)
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .notebookHeadline(16)
                    .foregroundStyle(AppTheme.ink)
                Text(subtitle)
                    .notebookCaption(12)
                    .foregroundStyle(AppTheme.ink.opacity(0.55))
            }
        }
        .tint(AppTheme.primary)
        .padding(16)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
