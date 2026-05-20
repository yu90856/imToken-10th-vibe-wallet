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
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var pendingAddress: String?

    private enum Flow {
        case welcome
        case importMnemonic
        case setPassword
        case createBackup
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    tokenCoreBadge
                    switch flow {
                    case .welcome:
                        welcomeStep
                    case .importMnemonic:
                        importStep
                    case .setPassword:
                        passwordStep
                    case .createBackup:
                        backupStep
                    }
                }
                .padding(24)
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
        case .importMnemonic, .setPassword:
            flow = .welcome
        case .createBackup:
            flow = .setPassword
            WalletKeychainStore.clearPendingWalletDraft()
            pendingAddress = nil
            mnemonic = ""
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
                Link(destination: ChainConfig.testnetFaucetURL) {
                    HStack(spacing: 6) {
                        SketchIcon(kind: .drop, size: 18, color: AppTheme.primary)
                        Text("領取 Sepolia ETH")
                            .notebookHeadline(18)
                    }
                }
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
            .buttonStyle(WalletPrimaryButtonStyle())
            .disabled(!walletSession.isTokenCoreReady)

            Button {
                beginImportWallet()
            } label: {
                Text("匯入助記詞")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(WalletSecondaryButtonStyle())
            .disabled(!walletSession.isTokenCoreReady)
        }
    }

    private func beginCreateWallet() {
        guard ensureTokenCoreReady() else { return }
        errorMessage = nil
        importText = ""
        mnemonic = ""
        WalletKeychainStore.clearPendingWalletDraft()
        pendingAddress = nil
        flow = .setPassword
    }

    private func beginImportWallet() {
        guard ensureTokenCoreReady() else { return }
        errorMessage = nil
        flow = .importMnemonic
    }

    private func ensureTokenCoreReady() -> Bool {
        if walletSession.isTokenCoreReady { return true }
        errorMessage = "Token Core 尚未就緒，請稍候或重新啟動 App。"
        Task { await walletSession.warmUpTokenCore() }
        return false
    }

    private var importStep: some View {
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
            .buttonStyle(WalletPrimaryButtonStyle())
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
                    Text(importText.isEmpty ? "建立錢包" : "匯入錢包")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(WalletPrimaryButtonStyle())
            .disabled(isBusy || walletPassword.count < 8 || walletPassword != confirmPassword)
        }
    }

    private var backupStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("備份助記詞")
                .font(.title3.weight(.bold))
            securityWarning

            Text(mnemonic)
                .font(.body.monospaced())
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                )

            Toggle("我已抄寫並妥善保存助記詞", isOn: $confirmedBackup)
                .font(.subheadline.weight(.medium))

            Button {
                Task { await finishAfterBackup() }
            } label: {
                Text("進入錢包")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(WalletPrimaryButtonStyle())
            .disabled(!confirmedBackup || isBusy)
        }
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
            if importText.isEmpty {
                let result = try await TokenCoreService.createWallet(password: walletPassword)
                try WalletKeychainStore.savePendingKeystoreJSON(result.keystoreJSON)
                WalletKeychainStore.savePendingAddress(result.address)
                mnemonic = result.mnemonic
                pendingAddress = result.address
                confirmedBackup = false
                #if DEBUG
                print("[TokenCore] 建立錢包成功，進入備份助記詞")
                #endif
                flow = .createBackup
            } else {
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
            walletPassword = ""
            confirmPassword = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct WalletPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .notebookHeadline(18)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.heroGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AppTheme.ink.opacity(0.2), lineWidth: 1)
                    )
                    .opacity(configuration.isPressed ? 0.88 : 1)
            )
    }
}

private struct WalletSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .notebookHeadline(18)
            .padding(.vertical, 14)
            .foregroundStyle(AppTheme.primary)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        AppTheme.primary,
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
                    )
            )
    }
}
