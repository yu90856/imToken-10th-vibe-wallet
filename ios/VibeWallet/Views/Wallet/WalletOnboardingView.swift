import SwiftUI

struct WalletOnboardingView: View {
    @Environment(WalletSession.self) private var walletSession
    @Environment(\.colorScheme) private var colorScheme
    @State private var flow: Flow = .welcome
    @State private var mnemonic = ""
    @State private var importText = ""
    @State private var walletPassword = ""
    @State private var confirmPassword = ""
    @State private var confirmedBackup = false
    @State private var mnemonicRevealed = false
    @State private var showRevealConfirm = false
    @State private var derivedPrivateKeyHex: String?
    @State private var derivationMismatch = false
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var pendingAddress: String?
    @State private var importPath: ImportPath = .none
    @State private var derivedImportAddress: String?

    private enum ImportPath {
        case none
        case mnemonic
        case privateKey
    }

    private enum Flow {
        case welcome
        case importMnemonic
        case importPrivateKey
        case setPassword
        case createBackup
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    tokenCoreBadge
                    Group {
                        switch flow {
                        case .welcome:
                            welcomeStep
                        case .importMnemonic:
                            importMnemonicStep
                        case .importPrivateKey:
                            importPrivateKeyStep
                        case .setPassword:
                            passwordStep
                        case .createBackup:
                            backupStep
                        }
                    }
                    .id(flow)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )
                }
                .padding(24)
                .animation(VibeMotion.navigationSpring, value: flow)
            }
            .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Vibe Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { onboardingToolbar }
            .onAppear { resumePendingBackupIfNeeded() }
        }
    }

    /// 建立到一半（已暫存 keystore）時回到備份步驟
    private func resumePendingBackupIfNeeded() {
        guard !walletSession.hasWallet,
              WalletKeychainStore.loadPendingKeystoreJSON() != nil else { return }
        if let address = WalletKeychainStore.loadPendingAddress() {
            pendingAddress = address
        }
        if flow != .createBackup {
            flow = .createBackup
        }
    }

    @ToolbarContentBuilder
    private var onboardingToolbar: some ToolbarContent {
        if flow != .welcome {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    goBackOneStep()
                } label: {
                    SketchIcon(kind: .chevronLeft, size: 22, color: AppTheme.primary)
                }
            }
        }
    }

    private func goBackOneStep() {
        errorMessage = nil
        switch flow {
        case .importMnemonic, .importPrivateKey, .setPassword:
            flow = .welcome
            importPath = .none
            importText = ""
            derivedImportAddress = nil
        case .createBackup:
            flow = .setPassword
            WalletKeychainStore.clearPendingWalletDraft()
            pendingAddress = nil
            mnemonic = ""
            mnemonicRevealed = false
            derivedPrivateKeyHex = nil
            derivationMismatch = false
        case .welcome:
            break
        }
    }

    private var tokenCoreBadge: some View {
        HStack(spacing: 6) {
            SketchIcon(kind: .chart, size: 16, color: AppTheme.primary)
            Text("Token Core · tcx-wasm")
                .notebookCaption(12)
        }
        .foregroundStyle(AppTheme.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(AppTheme.primary.opacity(0.12)))
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            SketchIcon(kind: .wallet, size: 52, color: AppTheme.primary)

            Text(ChainConfig.usesTestnet ? "Ethereum Sepolia 錢包" : "非託管 Ethereum 錢包")
                .notebookTitle(26)
                .foregroundStyle(AppTheme.ink(for: colorScheme))

            Text("助記詞與 keystore 由 Token Core 在本機 WASM 處理。建立後請領取 Sepolia ETH 做交易測試。")
                .notebookBody(16)
                .foregroundStyle(AppTheme.secondaryInk(for: colorScheme))

            BNBChainBadge()

            if ChainConfig.usesTestnet {
                Text("建立或匯入錢包後，會提示你用 Google 帳號領取 Sepolia 測試 ETH。")
                    .notebookCaption(12)
                    .foregroundStyle(AppTheme.secondaryInk(for: colorScheme))
            }

            if !walletSession.isTokenCoreReady {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Token Core 載入中…（首次約需 10–30 秒）")
                        .notebookCaption(12)
                        .foregroundStyle(AppTheme.secondaryInk(for: colorScheme))
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.negative)
            }

            Button {
                beginCreateWallet()
            } label: {
                Text("建立新錢包")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(VibePrimaryButtonStyle())
            .disabled(!walletSession.isTokenCoreReady)

            Button {
                beginImportWallet()
            } label: {
                Text("匯入助記詞")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(VibeSecondaryButtonStyle())
            .disabled(!walletSession.isTokenCoreReady)

            Button {
                beginImportPrivateKey()
            } label: {
                Text("匯入私鑰")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(VibeSecondaryButtonStyle())
        }
    }

    private func beginCreateWallet() {
        guard ensureTokenCoreReady() else { return }
        errorMessage = nil
        importPath = .none
        importText = ""
        derivedImportAddress = nil
        mnemonic = ""
        WalletKeychainStore.clearPendingWalletDraft()
        pendingAddress = nil
        flow = .setPassword
    }

    private func beginImportWallet() {
        guard ensureTokenCoreReady() else { return }
        errorMessage = nil
        importPath = .mnemonic
        importText = ""
        derivedImportAddress = nil
        flow = .importMnemonic
    }

    private func beginImportPrivateKey() {
        errorMessage = nil
        importPath = .privateKey
        importText = ""
        derivedImportAddress = nil
        flow = .importPrivateKey
    }

    private func ensureTokenCoreReady() -> Bool {
        if walletSession.isTokenCoreReady { return true }
        errorMessage = "Token Core 尚未就緒，請稍候或重新啟動 App。"
        Task { await walletSession.warmUpTokenCore() }
        return false
    }

    private var importMnemonicStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("匯入助記詞")
                .font(.title3.weight(.bold))
            securityWarning

            TextField("12 或 24 個英文單字，以空格分隔", text: $importText, axis: .vertical)
                .lineLimit(3...6)
                .padding(14)
                .background(fieldShape)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(AppTheme.negative)
            }

            Button {
                Task { await validateImport() }
            } label: {
                Text("下一步：設定密碼")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(VibePrimaryButtonStyle())
            .disabled(isBusy)
        }
    }

    private var importPrivateKeyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("匯入私鑰")
                .font(.title3.weight(.bold))
            privateKeySecurityWarning

            SecureField("64 位十六進制私鑰（可含 0x）", text: $importText)
                .padding(14)
                .background(fieldShape)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.password)

            if let derivedImportAddress {
                Text("對應地址：\(derivedImportAddress)")
                    .font(.caption.monospaced())
                    .foregroundStyle(AppTheme.secondaryInk(for: colorScheme))
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(AppTheme.negative)
            }

            Button {
                Task { await validatePrivateKeyImport() }
            } label: {
                Text("下一步：設定密碼")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(VibePrimaryButtonStyle())
            .disabled(isBusy)
        }
    }

    private var passwordStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("錢包解鎖密碼")
                .font(.title3.weight(.bold))
            Text("用於加密 Token Core keystore，僅存於本機。")
                .font(.caption)
                .foregroundStyle(.secondary)

            SecureField("至少 8 碼", text: $walletPassword)
                .padding(14)
                .background(fieldShape)
            SecureField("再次輸入", text: $confirmPassword)
                .padding(14)
                .background(fieldShape)

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(AppTheme.negative)
            }

            Button {
                Task { await submitPassword() }
            } label: {
                HStack {
                    if isBusy { ProgressView().tint(.white) }
                    Text(passwordStepActionTitle)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(VibePrimaryButtonStyle())
            .disabled(isBusy || walletPassword.count < 8 || walletPassword != confirmPassword)
        }
    }

    private var backupStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("備份助記詞與私鑰")
                .font(.title3.weight(.bold))
            mnemonicBackupDangerWarning

            if let pendingAddress {
                Text("錢包地址：\(pendingAddress)")
                    .font(.caption.monospaced())
                    .foregroundStyle(AppTheme.secondaryInk(for: colorScheme))
            }

            sensitiveSecretCard(
                title: "助記詞（12 / 24 詞）",
                secret: mnemonic,
                revealed: mnemonicRevealed
            )

            if let derivedPrivateKeyHex, !derivationMismatch {
                sensitiveSecretCard(
                    title: "對應私鑰（僅本機推導，用於備份）",
                    secret: "0x\(derivedPrivateKeyHex)",
                    revealed: mnemonicRevealed
                )
            } else if derivationMismatch {
                Text("私鑰與上方地址不一致，請勿使用畫面私鑰；僅手寫助記詞，並以地址欄為準。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.warning)
            }

            if !mnemonicRevealed {
                Button {
                    showRevealConfirm = true
                } label: {
                    Label("顯示助記詞與私鑰", systemImage: "eye.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(VibeSecondaryButtonStyle())
            }

            Toggle("我已手寫抄錄，並了解不可截圖、拍照或上傳雲端", isOn: $confirmedBackup)
                .font(.subheadline.weight(.medium))
                .disabled(!mnemonicRevealed)

            Button {
                Task { await finishAfterBackup() }
            } label: {
                Text("進入錢包")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(VibePrimaryButtonStyle())
            .disabled(!confirmedBackup || !mnemonicRevealed || isBusy)
        }
        .onAppear { refreshDerivedPrivateKeyIfNeeded() }
        .alert("顯示敏感資訊", isPresented: $showRevealConfirm) {
            Button("取消", role: .cancel) {}
            Button("我了解風險", role: .destructive) {
                mnemonicRevealed = true
            }
        } message: {
            Text(
                """
                助記詞或私鑰一旦外洩（截圖、相簿、聊天軟體、螢幕錄影），他人可轉走你的全部資產。
                請在無人窺視的環境下手寫抄錄，不要使用截圖或複製到雲端。
                """
            )
        }
    }

    private func sensitiveSecretCard(title: String, secret: String, revealed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryInk(for: colorScheme))

            ZStack(alignment: .center) {
                Text(secret)
                    .font(.body.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .blur(radius: revealed ? 0 : 14)
                    .opacity(revealed ? 1 : 0.35)
                    .accessibilityHidden(!revealed)

                if !revealed {
                    VStack(spacing: 6) {
                        Image(systemName: "eye.slash.fill")
                            .font(.title2)
                        Text("點下方按鈕並確認後顯示")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(AppTheme.secondaryInk(for: colorScheme))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppTheme.warning.opacity(revealed ? 0 : 0.35), lineWidth: 1)
            )
        }
        .privacySensitive()
    }

    private var mnemonicBackupDangerWarning: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("極重要 · 請勿外洩", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.negative)
            Text("助記詞或私鑰等同資產控制權。任何人取得後可轉走你的加密資產，且無法追回。")
                .font(.caption)
                .foregroundStyle(AppTheme.ink.opacity(0.85))
            VStack(alignment: .leading, spacing: 4) {
                backupBullet("請勿截圖、螢幕錄影或存入相簿")
                backupBullet("請勿透過微信、Telegram、Email 等傳送")
                backupBullet("請勿輸入到任何網站、AI 工具或他人裝置")
                backupBullet("建議手寫抄錄並離線妥善保管")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.negative.opacity(0.1))
        )
    }

    private func backupBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
            Text(text)
        }
    }

    private func refreshDerivedPrivateKeyIfNeeded() {
        guard importPath == .none, !mnemonic.isEmpty else { return }
        Task { @MainActor in
            do {
                let hex = try EthereumMnemonicDerivation.privateKeyHex(mnemonic: mnemonic)
                derivedPrivateKeyHex = hex
                if let pendingAddress {
                    derivationMismatch = !EthereumMnemonicDerivation.verifyMatchesAddress(
                        mnemonic: mnemonic,
                        expectedAddress: pendingAddress
                    )
                } else {
                    derivationMismatch = false
                }
            } catch {
                derivedPrivateKeyHex = nil
                derivationMismatch = true
            }
        }
    }

    private var passwordStepActionTitle: String {
        switch importPath {
        case .none: return "建立錢包"
        case .mnemonic, .privateKey: return "匯入錢包"
        }
    }

    private var privateKeySecurityWarning: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("私鑰風險", systemImage: "exclamationmark.shield.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.warning)
            Text("私鑰等同完整資產控制權。請勿截圖、複製到雲端或聊天軟體。匯入前請確認地址與你的錢包一致。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.warning.opacity(0.12))
        )
    }

    private var securityWarning: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("安全提醒", systemImage: "exclamationmark.shield.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.warning)
            Text("請勿截圖或透過聊天軟體傳送助記詞。任何人取得助記詞即可轉走資產。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.warning.opacity(0.12))
        )
    }

    private var fieldShape: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
    }

    @MainActor
    private func validatePrivateKeyImport() async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        guard let normalized = ExternalPrivateKeyService.normalizePrivateKey(importText) else {
            errorMessage = WalletError.invalidPrivateKey.localizedDescription
            derivedImportAddress = nil
            return
        }
        do {
            let address = try ExternalPrivateKeyService.ethereumAddress(fromPrivateKeyHex: normalized)
            derivedImportAddress = address
            flow = .setPassword
        } catch {
            errorMessage = WalletError.invalidPrivateKey.localizedDescription
            derivedImportAddress = nil
        }
    }

    @MainActor
    private func validateImport() async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        let normalized = TokenCoreService.normalizeMnemonic(importText)
        guard await TokenCoreService.isValidMnemonic(normalized) else {
            errorMessage = WalletError.invalidMnemonic.localizedDescription
            return
        }
        mnemonic = normalized
        importPath = .mnemonic
        flow = .setPassword
    }

    @MainActor
    private func submitPassword() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        #if DEBUG
        print("[TokenCore] 使用者按下建立／匯入錢包")
        #endif
        do {
            try await TokenCoreBridge.shared.ensureReady()
            await walletSession.warmUpTokenCore()
            if importPath == .privateKey {
                _ = try await walletSession.importPrivateKey(importText, walletPassword: walletPassword)
            } else if importPath == .none {
                let result = try await TokenCoreService.createWallet(password: walletPassword)
                try WalletKeychainStore.savePendingKeystoreJSON(result.keystoreJSON)
                WalletKeychainStore.savePendingAddress(result.address)
                mnemonic = result.mnemonic
                pendingAddress = result.address
                confirmedBackup = false
                mnemonicRevealed = false
                derivedPrivateKeyHex = nil
                derivationMismatch = false
                #if DEBUG
                print("[TokenCore] 建立錢包成功，進入備份助記詞")
                #endif
                flow = .createBackup
            } else if importPath == .mnemonic {
                _ = try await walletSession.importWallet(
                    mnemonic: mnemonic,
                    walletPassword: walletPassword
                )
            }
        } catch {
            #if DEBUG
            print("[TokenCore] 建立失敗：\(error.localizedDescription)")
            #endif
            errorMessage = error.localizedDescription
            await walletSession.warmUpTokenCore()
        }
    }

    @MainActor
    private func finishAfterBackup() async {
        if walletSession.hasWallet {
            WalletKeychainStore.clearPendingWalletDraft()
            return
        }

        guard let keystore = WalletKeychainStore.loadPendingKeystoreJSON() else {
            errorMessage = "錢包資料遺失，請返回重新建立。"
            flow = .welcome
            WalletKeychainStore.clearPendingWalletDraft()
            pendingAddress = nil
            return
        }
        let address = pendingAddress ?? WalletKeychainStore.loadPendingAddress()
        guard let address else {
            errorMessage = "錢包資料遺失，請返回重新建立。"
            flow = .welcome
            WalletKeychainStore.clearPendingWalletDraft()
            pendingAddress = nil
            return
        }

        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try walletSession.finalizeCreatedWallet(
                keystoreJSON: keystore,
                address: address,
                password: walletPassword
            )
            WalletKeychainStore.clearPendingWalletDraft()
            mnemonic = ""
            mnemonicRevealed = false
            derivedPrivateKeyHex = nil
            derivationMismatch = false
            walletPassword = ""
            confirmPassword = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
