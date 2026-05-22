import SwiftUI

struct WalletTransferSheet: View {
    enum Mode {
        case send
        case receive
    }

    let mode: Mode
    var holdings: [HoldingAsset] = []
    var preselectedHoldingId: String?
    var isDecoy: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(WalletSession.self) private var walletSession

    @State private var selectedHoldingId: String?
    @State private var toAddress = ""
    @State private var amount = ""
    @State private var chainBalance: Decimal?
    @State private var isLoadingBalance = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var txHash: String?
    @State private var showWalletPassword = false
    @State private var showTransactionPIN = false
    @State private var copiedAddress = false

    private var sendableHoldings: [HoldingAsset] {
        holdings.filter { WalletTransferService.assetKind(for: $0.id) != nil }
    }

    private var selectedHolding: HoldingAsset? {
        guard let id = selectedHoldingId else { return nil }
        return holdings.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: VibeSpacing.medium) {
                    if mode == .receive {
                        receiveContent
                    } else {
                        sendContent
                    }
                }
                .padding(VibeSpacing.large)
            }
            .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle(mode == .send ? "發送" : "接收")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(AppTheme.primary)
                }
            }
            .task(id: selectedHoldingId) {
                await refreshChainBalance()
            }
            .sheet(isPresented: $showWalletPassword) {
                WalletPasswordSheet(
                    onUnlocked: {
                        showWalletPassword = false
                        Task { await performSend() }
                    },
                    onCancel: { showWalletPassword = false }
                )
            }
            .sheet(isPresented: $showTransactionPIN) {
                TransactionPINEntrySheet(mode: .verify) { success in
                    showTransactionPIN = false
                    if success { continueSendAfterTxAuth() }
                }
            }
        }
        .presentationDetents([.large])
        .vibePresentedScreen()
        .onAppear {
            if selectedHoldingId == nil {
                selectedHoldingId = preselectedHoldingId
                    ?? sendableHoldings.first?.id
            }
        }
    }

    private var displayAddress: String {
        if isDecoy { return MockDuressWalletData.fakeAddress }
        return walletSession.account?.address ?? "尚未建立錢包"
    }

    private var receiveContent: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.small) {
            Text("掃描或複製地址，即可接收 \(ChainConfig.active.symbol) 與同鏈代幣。")
                .notebookBody(14)
                .foregroundStyle(AppTheme.secondaryInk(for: colorScheme))

            Text(displayAddress)
                .font(NotebookFont.caption(12))
                .monospaced()
                .foregroundStyle(AppTheme.ink(for: colorScheme))
                .padding(VibeSpacing.small)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 12, variant: .yellow)

            Button {
                UIPasteboard.general.string = displayAddress
                copiedAddress = true
                VibeHaptics.success()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    copiedAddress = false
                }
            } label: {
                Text(copiedAddress ? "已複製" : "複製地址")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(VibePrimaryButtonStyle())
        }
    }

    private var sendContent: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.medium) {
            if sendableHoldings.isEmpty {
                ContentUnavailableView(
                    "尚無可轉出代幣",
                    systemImage: "tray",
                    description: Text("請先在 Sepolia 領取測試 ETH，或完成質押／交換取得演示代幣。")
                )
            } else {
                tokenPickerSection
                amountSection
                recipientSection
                if let txHash {
                    successSection(hash: txHash)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .notebookCaption(12)
                        .foregroundStyle(AppTheme.negative)
                }
                Button(action: beginSend) {
                    HStack {
                        if isSending { ProgressView().tint(.white) }
                        Text(isSending ? "廣播中…" : "確認發送")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(VibePrimaryButtonStyle())
                .disabled(!canSubmitSend || isSending || txHash != nil)
            }
        }
    }

    private var tokenPickerSection: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.xSmall) {
            Text("發送代幣")
                .notebookCaption(12)
                .foregroundStyle(AppTheme.secondaryInk(for: colorScheme))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VibeSpacing.xSmall) {
                    ForEach(sendableHoldings) { holding in
                        tokenChip(holding)
                    }
                }
            }

            if let holding = selectedHolding, let chainBalance {
                HStack {
                    Text("可用餘額")
                        .notebookCaption(11)
                        .foregroundStyle(AppTheme.secondaryInk(for: colorScheme))
                    Spacer()
                    Text("\(WalletOnChainHoldingsService.formatAmount(chainBalance)) \(holding.symbol)")
                        .notebookBody(14)
                        .foregroundStyle(AppTheme.ink(for: colorScheme))
                }
            } else if isLoadingBalance {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private func tokenChip(_ holding: HoldingAsset) -> some View {
        let selected = holding.id == selectedHoldingId
        return Button {
            selectedHoldingId = holding.id
            amount = ""
            errorMessage = nil
            VibeHaptics.selection()
        } label: {
            HStack(spacing: 8) {
                TokenLogoView(tokenId: holding.id, symbol: holding.symbol, imageURL: holding.imageURL, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(holding.symbol)
                        .notebookHeadline(14)
                    Text(holding.balance)
                        .notebookCaption(10)
                        .foregroundStyle(AppTheme.secondaryInk(for: colorScheme))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected
                        ? AppTheme.primary.opacity(0.18)
                        : AppTheme.stickyNoteFill(for: colorScheme, variant: .mint))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        selected ? AppTheme.primary : AppTheme.fieldStroke(for: colorScheme),
                        lineWidth: selected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.xSmall) {
            HStack {
                Text("數量")
                    .notebookCaption(12)
                Spacer()
                if chainBalance != nil {
                    Button("全部") { fillMaxAmount() }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }
            }
            TextField("0.0", text: $amount)
                .keyboardType(.decimalPad)
                .font(NotebookFont.body(16))
                .padding(VibeSpacing.small)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.fieldFill(for: colorScheme))
                )
            if let holding = selectedHolding {
                Text("將發送 \(holding.symbol)（\(holding.name)）")
                    .notebookCaption(11)
                    .foregroundStyle(AppTheme.secondaryInk(for: colorScheme))
            }
        }
    }

    private var recipientSection: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.xSmall) {
            Text("收款地址")
                .notebookCaption(12)
            VibeTextField(placeholder: "0x…", text: $toAddress)
        }
    }

    private func successSection(hash: String) -> some View {
        VStack(alignment: .leading, spacing: VibeSpacing.xSmall) {
            Label("交易已送出", systemImage: "checkmark.circle.fill")
                .notebookHeadline(16)
                .foregroundStyle(AppTheme.positive)
            if let url = URL(string: "\(ChainConfig.active.explorerURL)/tx/\(hash)") {
                Link("在 Etherscan 查看", destination: url)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(VibeSpacing.small)
        .glassCard(cornerRadius: 12, variant: .mint)
    }

    private var canSubmitSend: Bool {
        guard selectedHoldingId != nil,
              !toAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              parseAmount(amount) != nil else { return false }
        return true
    }

    private func fillMaxAmount() {
        guard let bal = chainBalance, let holding = selectedHolding else { return }
        if holding.id == "eth-native" {
            let maxSend = max(0, bal - SepoliaSwapDemoConfig.gasReserveEther)
            amount = WalletOnChainHoldingsService.formatAmount(maxSend, maxFraction: 8)
        } else {
            amount = WalletOnChainHoldingsService.formatAmount(bal, maxFraction: 8)
        }
    }

    @MainActor
    private func refreshChainBalance() async {
        guard mode == .send,
              !isDecoy,
              let id = selectedHoldingId,
              let address = walletSession.account?.address else {
            chainBalance = nil
            return
        }
        isLoadingBalance = true
        defer { isLoadingBalance = false }
        chainBalance = await WalletTransferService.balance(for: id, walletAddress: address)
    }

    private func beginSend() {
        if isDecoy {
            Task { @MainActor in
                DuressModeController.shared.recordHostileAction()
            }
            return
        }
        errorMessage = nil
        Task { @MainActor in
            do {
                let reason = "確認發送 \(selectedHolding?.symbol ?? "代幣")"
                switch try await SigningUnlockCoordinator.prepareForSigning(reason: reason) {
                case .readyToSign:
                    await performSend()
                case .needWalletPassword:
                    showWalletPassword = true
                }
            } catch TransactionAuthError.pinRequired {
                showTransactionPIN = true
            } catch TransactionAuthError.pinNotSet {
                errorMessage = TransactionAuthError.pinNotSet.localizedDescription
            } catch {
                if !(error is TransactionAuthError) {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    @MainActor
    private func continueSendAfterTxAuth() {
        Task {
            let reason = "解鎖以發送 \(selectedHolding?.symbol ?? "代幣")"
            switch try? await SigningUnlockCoordinator.prepareForSigning(reason: reason) {
            case .readyToSign:
                await performSend()
            case .needWalletPassword, .none:
                showWalletPassword = true
            }
        }
    }

    @MainActor
    private func performSend() async {
        guard let holdingId = selectedHoldingId,
              let walletAddress = walletSession.account?.address,
              let password = walletSession.signingPassword,
              let sendAmount = parseAmount(amount) else {
            showWalletPassword = true
            return
        }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            let hash = try await WalletTransferService.send(
                holdingId: holdingId,
                toAddress: toAddress,
                amount: sendAmount,
                walletAddress: walletAddress,
                walletPassword: password
            )
            txHash = hash
            VibeHaptics.success()
            await WalletActivityMonitor.shared.notifyOutgoingTransfer(
                holdingId: holdingId,
                amount: sendAmount,
                txHash: hash
            )
            await refreshChainBalance()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func parseAmount(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
        guard !trimmed.isEmpty, let value = Decimal(string: trimmed), value > 0 else { return nil }
        return value
    }
}
