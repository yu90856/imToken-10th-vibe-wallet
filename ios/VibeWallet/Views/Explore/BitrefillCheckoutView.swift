import SwiftUI

struct BitrefillCheckoutView: View {
    let invoice: BitrefillInvoiceSummary

    @Environment(WalletSession.self) private var walletSession
    @Environment(\.colorScheme) private var colorScheme

    @State private var liveInvoice: BitrefillInvoiceSummary
    @State private var isPaying = false
    @State private var isPolling = false
    @State private var alertMessage: String?
    @State private var txHash: String?
    @State private var showWalletPassword = false
    @State private var showTransactionPIN = false
    @State private var redemption: BitrefillRedemptionInfo?
    @State private var navigateOrder = false

    init(invoice: BitrefillInvoiceSummary) {
        self.invoice = invoice
        _liveInvoice = State(initialValue: invoice)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                summaryCard
                paymentCard
                actionButtons
                if let txHash {
                    txResultCard(txHash)
                }
                if let redemption {
                    redemptionCard(redemption)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
        .navigationTitle("確認付款")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateOrder) {
            BitrefillOrderStatusView(
                invoiceId: liveInvoice.id,
                orderId: liveInvoice.orderId,
                initialRedemption: redemption
            )
        }
        .task { await refreshInvoice() }
        .alert("Bitrefill", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("了解", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .sheet(isPresented: $showWalletPassword) {
            WalletPasswordSheet(
                onUnlocked: {
                    showWalletPassword = false
                    Task { await payWithWallet() }
                },
                onCancel: { showWalletPassword = false }
            )
        }
        .sheet(isPresented: $showTransactionPIN) {
            TransactionPINEntrySheet(mode: .verify) { success in
                showTransactionPIN = false
                if success { continueWalletPaymentAfterTxAuth() }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(liveInvoice.productName)
                .notebookHeadline(17)
            Text(liveInvoice.packageLabel)
                .notebookBody(14)
            Text("訂單狀態：\(liveInvoice.status)")
                .notebookCaption(12)
                .foregroundStyle(AppTheme.ink.opacity(0.55))
        }
        .padding(16)
        .glassCard(cornerRadius: 16, variant: .mint)
    }

    private var paymentCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("付款資訊")
                .notebookHeadline(16)
            Text("方式：\(liveInvoice.paymentMethod) · \(liveInvoice.paymentCurrency ?? "")")
                .notebookCaption(12)
            if let address = liveInvoice.paymentAddress {
                Text("收款地址")
                    .notebookCaption(11)
                    .foregroundStyle(AppTheme.ink.opacity(0.5))
                Text(address)
                    .font(NotebookFont.caption(11))
                    .monospaced()
            }
            if let wei = liveInvoice.paymentAmountWei {
                let eth = NSDecimalNumber(decimal: EVMWeiFormatter.weiToEther(wei)).stringValue
                Text("金額：約 \(eth) ETH（主網，依 Bitrefill 帳單）")
                    .notebookBody(14)
            }
            Text("付款狀態：\(liveInvoice.paymentStatus ?? "—")")
                .notebookCaption(12)
                .foregroundStyle(AppTheme.ink.opacity(0.55))
            Text("Bitrefill 使用以太坊主網收款；與 App 內 Sepolia 測試資產分開。需有少量主網 ETH。")
                .notebookCaption(11)
                .foregroundStyle(AppTheme.ink.opacity(0.45))
        }
        .padding(16)
        .glassCard(cornerRadius: 16, variant: .yellow)
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                showWalletPassword = true
            } label: {
                Text(isPaying ? "簽名廣播中…" : "用錢包付款（主網 ETH）")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.heroGradient))
            }
            .disabled(isPaying || liveInvoice.paymentAddress == nil)

            Button {
                Task { await payFromBalance() }
            } label: {
                Text("使用 Bitrefill 帳戶餘額付款")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(AppTheme.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(AppTheme.primary.opacity(0.35), lineWidth: 1)
                    )
            }
            .disabled(isPaying)

            Button {
                Task { await refreshInvoice() }
            } label: {
                Text(isPolling ? "更新狀態中…" : "重新整理訂單狀態")
                    .notebookCaption(12)
            }
            .buttonStyle(.plain)
        }
    }

    private func txResultCard(_ hash: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("交易已廣播")
                .notebookHeadline(15)
            Link("在 Etherscan 查看", destination: URL(string: "\(ChainConfig.ethereumMainnet.explorerURL)/tx/\(hash)")!)
                .font(.caption.weight(.semibold))
        }
        .padding(14)
        .glassCard(cornerRadius: 14, variant: .pink)
    }

    private func redemptionCard(_ info: BitrefillRedemptionInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("兌換資訊")
                .notebookHeadline(15)
            if let code = info.code {
                Text(code)
                    .font(NotebookFont.body(18))
                    .monospaced()
            }
            if let instructions = info.instructions {
                Text(instructions)
                    .notebookCaption(12)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 14, variant: .mint)
    }

    @MainActor
    private func refreshInvoice() async {
        isPolling = true
        defer { isPolling = false }
        if case .success(let updated) = await BitrefillCommerceService.fetchInvoice(id: liveInvoice.id) {
            liveInvoice = updated
            if updated.paymentStatus == "confirmed" || updated.status.contains("complete") {
                await loadRedemption()
                navigateOrder = true
            }
        }
    }

    @MainActor
    private func payFromBalance() async {
        isPaying = true
        defer { isPaying = false }
        switch await BitrefillCommerceService.payInvoiceFromBalance(id: liveInvoice.id) {
        case .success(let updated):
            liveInvoice = updated
            alertMessage = "已嘗試以 Bitrefill 餘額付款。若餘額不足請改用錢包付款。"
            await refreshInvoice()
        case .failure(let error):
            alertMessage = error.localizedDescription
        }
    }

    private func beginWalletPayment() {
        guard walletSession.hasWallet, walletSession.account != nil else {
            alertMessage = "請先建立或匯入錢包"
            return
        }
        Task { @MainActor in
            do {
                switch try await SigningUnlockCoordinator.prepareForSigning(reason: "確認 Bitrefill 付款") {
                case .readyToSign:
                    await payWithWallet()
                case .needWalletPassword:
                    showWalletPassword = true
                }
            } catch TransactionAuthError.pinRequired {
                showTransactionPIN = true
            } catch TransactionAuthError.pinNotSet {
                alertMessage = TransactionAuthError.pinNotSet.localizedDescription
            } catch {
                if !(error is TransactionAuthError) {
                    alertMessage = error.localizedDescription
                }
            }
        }
    }

    @MainActor
    private func continueWalletPaymentAfterTxAuth() {
        Task {
            switch try? await SigningUnlockCoordinator.prepareForSigning(reason: "解鎖以支付 Bitrefill 訂單") {
            case .readyToSign:
                await payWithWallet()
            case .needWalletPassword, .none:
                showWalletPassword = true
            }
        }
    }

    @MainActor
    private func payWithWallet() async {
        guard let address = walletSession.account?.address,
              let password = walletSession.signingPassword,
              let keystore = WalletKeychainStore.loadKeystoreJSON() else {
            showWalletPassword = true
            return
        }
        isPaying = true
        defer { isPaying = false }
        do {
            let hash = try await BitrefillPaymentService.sendEthereumInvoicePayment(
                walletAddress: address,
                keystoreJSON: keystore,
                password: password,
                invoice: liveInvoice
            )
            txHash = hash
            alertMessage = "付款交易已送出，請稍候確認…"
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await refreshInvoice()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadRedemption() async {
        guard let orderId = liveInvoice.orderId else { return }
        if case .success(let info) = await BitrefillCommerceService.fetchRedemption(orderId: orderId) {
            redemption = info
        }
    }
}
