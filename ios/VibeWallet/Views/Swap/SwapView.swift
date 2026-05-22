import SwiftUI

struct SwapView: View {
    @State private var viewModel: SwapViewModel
    @Environment(WalletSession.self) private var walletSession
    @Environment(\.colorScheme) private var colorScheme
    @State private var pickerTarget: TokenPickerTarget?
    @State private var showSwapConfirm = false
    @State private var showPINAuth = false
    @State private var showPinNotSetAlert = false
    @State private var showWalletPassword = false
    @State private var authErrorMessage: String?
    @State private var swapResultMessage: String?
    private let showsSubpageNavigation: Bool
    private let preselectedTo: MarketToken?

    enum TokenPickerTarget: Identifiable {
        case from
        case to

        var id: String {
            switch self {
            case .from: return "from"
            case .to: return "to"
            }
        }
    }

    init(preselectedTo: MarketToken? = nil, showsSubpageNavigation: Bool = false) {
        self.preselectedTo = preselectedTo
        self.showsSubpageNavigation = showsSubpageNavigation
        _viewModel = State(initialValue: SwapViewModel(preselectedTo: preselectedTo))
    }

    private var refreshTaskKey: String {
        "\(walletSession.account?.address ?? "none")|\(preselectedTo?.id ?? "default")"
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if ChainConfig.usesTestnet {
                    sepoliaHintCard
                }
                swapCard
                quoteSection
                if let msg = viewModel.lastSwapMessage {
                    swapResultCard(msg)
                }
                swapButton
            }
            .padding(20)
            .padding(.bottom, 8)
        }
        .walletDeckScrollInset()
        .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
        .navigationTitle("交換")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(OptionalSubpageNav(shows: showsSubpageNavigation, backTitle: "返回"))
        .sheet(item: $pickerTarget) { target in
            SwapTokenPickerSheet(
                title: target == .from ? "支付代幣" : "接收代幣",
                tokens: target == .from
                    ? viewModel.fromTokensForPicker
                    : viewModel.allReceivableTokens(),
                selectedID: target == .from ? viewModel.fromToken?.id : viewModel.toToken?.id
            ) { token in
                if target == .from {
                    viewModel.fromToken = token
                } else {
                    viewModel.toToken = token
                }
                viewModel.onTokenChanged()
            }
        }
        .sheet(isPresented: $showPINAuth) {
            TransactionPINEntrySheet(mode: .verify) { success in
                if success { showSwapConfirm = true }
            }
        }
        .alert("請先設定交易密碼", isPresented: $showPinNotSetAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("請到首頁右上角「設定」建立 4 碼交易密碼，或開啟 Face ID 確認。")
        }
        .alert("驗證失敗", isPresented: Binding(
            get: { authErrorMessage != nil },
            set: { if !$0 { authErrorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) { authErrorMessage = nil }
        } message: {
            Text(authErrorMessage ?? "")
        }
        .sheet(isPresented: $showWalletPassword) {
            WalletPasswordSheet(
                onUnlocked: {
                    showWalletPassword = false
                    Task { await performSwap() }
                },
                onCancel: { showWalletPassword = false }
            )
        }
        .alert("確認交換", isPresented: $showSwapConfirm) {
            Button("取消", role: .cancel) {}
            Button("確認並廣播") { continueAfterSwapConfirm() }
        } message: {
            if viewModel.canExecuteOnChain {
                Text("將在 Sepolia 廣播真實交易。請確認代幣對與數量無誤。")
            } else {
                Text(viewModel.swapDisabledReason ?? "無法執行鏈上交換")
            }
        }
        .alert("交換", isPresented: Binding(
            get: { swapResultMessage != nil },
            set: { if !$0 { swapResultMessage = nil } }
        )) {
            Button("了解", role: .cancel) {}
        } message: {
            Text(swapResultMessage ?? "")
        }
        .task(id: refreshTaskKey) {
            await viewModel.refreshTokens(preselectedTo: preselectedTo)
        }
        .onReceive(NotificationCenter.default.publisher(for: .walletBalancesDidChange)) { _ in
            Task { await viewModel.refreshTokens(preselectedTo: preselectedTo) }
        }
    }

    private var sepoliaHintCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sepolia 鏈上交換")
                .notebookHeadline(15)
            Text("行情進入：USDT → 該幣種（CoinGecko 參考）。跨鏈資產會顯示「跨鏈橋」路徑；僅 ETH ↔ vUSDC / ETH → pufETH 可 Sepolia 鏈上廣播。")
                .notebookCaption(12)
                .foregroundStyle(AppTheme.ink.opacity(0.7))
            if !SepoliaSwapDemoConfig.hasOnChainSwap {
                Text("尚未配置 vUSDC 合約：執行 node scripts/setup-swap-sepolia.mjs")
                    .notebookCaption(11)
                    .foregroundStyle(AppTheme.warning)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 14, variant: .mint)
    }

    private func swapResultCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message)
                .notebookBody(14)
                .foregroundStyle(AppTheme.positive)
            if let hash = viewModel.lastTxHash,
               let url = URL(string: "\(ChainConfig.active.explorerURL)/tx/\(hash)") {
                Link("在 Etherscan 查看", destination: url)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 14, variant: .yellow)
    }

    @MainActor
    private func continueAfterSwapConfirm() {
        guard walletSession.hasWallet, walletSession.account != nil else { return }
        Task {
            do {
                switch try await SigningUnlockCoordinator.prepareForSigning(reason: "確認 Sepolia 鏈上交換") {
                case .readyToSign:
                    await performSwap()
                case .needWalletPassword:
                    showWalletPassword = true
                }
            } catch TransactionAuthError.pinRequired {
                showPINAuth = true
            } catch TransactionAuthError.pinNotSet {
                showPinNotSetAlert = true
            } catch {
                if let error = error as? LocalizedError, let msg = error.errorDescription {
                    authErrorMessage = msg
                } else {
                    authErrorMessage = error.localizedDescription
                }
            }
        }
    }

    @MainActor
    private func performSwap() async {
        guard let address = walletSession.account?.address,
              let password = walletSession.signingPassword else {
            showWalletPassword = true
            return
        }
        do {
            try await viewModel.executeSwap(walletAddress: address, walletPassword: password)
            swapResultMessage = viewModel.lastSwapMessage
        } catch {
            swapResultMessage = error.localizedDescription
        }
    }

    @MainActor
    private func beginSwapPreview() async {
        guard viewModel.canExecuteOnChain else {
            swapResultMessage = viewModel.swapDisabledReason ?? "此代幣對不支援 Sepolia 鏈上交換"
            return
        }
        showSwapConfirm = true
    }

    private var swapCard: some View {
        VStack(spacing: 12) {
            swapAmountRow(
                label: "支付",
                token: viewModel.fromToken,
                amountText: viewModel.amountFromText,
                onAmountChange: { viewModel.updateFromAmount($0) },
                balance: viewModel.fromBalanceLabel,
                onMax: { viewModel.setMaxFromAmount() },
                onPickToken: { pickerTarget = .from }
            )

            HStack {
                Spacer()
                Button {
                    withAnimation { viewModel.swapDirection() }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.primary)
                }
                Spacer()
            }

            swapAmountRow(
                label: "接收",
                token: viewModel.toToken,
                amountText: viewModel.amountToText,
                onAmountChange: { viewModel.updateToAmount($0) },
                balance: nil,
                onMax: nil,
                onPickToken: { pickerTarget = .to }
            )
        }
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    private func swapAmountRow(
        label: String,
        token: MarketToken?,
        amountText: String,
        onAmountChange: @escaping (String) -> Void,
        balance: String?,
        onMax: (() -> Void)?,
        onPickToken: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onPickToken) {
                HStack(spacing: 10) {
                    if let token {
                        TokenLogoView(tokenId: token.id, symbol: token.symbol, imageURL: token.imageURL, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(token.symbol)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)
                        }
                    } else {
                        Text("選擇 \(label) 代幣")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if let balance {
                HStack {
                    Text(balance)
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    if let onMax {
                        Button("最大", action: onMax)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.primary)
                    }
                }
            }

            TextField(
                "0.0",
                text: Binding(
                    get: { amountText },
                    set: { @Sendable newValue in
                        MainActor.assumeIsolated {
                            onAmountChange(newValue)
                        }
                    }
                )
            )
            .keyboardType(.decimalPad)
            .font(.title2.weight(.semibold))
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.8))
        )
    }

    private var quoteSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("報價詳情")
                .font(.headline.weight(.bold))

            quoteRow("路徑", viewModel.quote.routeDescription)
            quoteRow("匯率", viewModel.quote.exchangeRate)
            quoteRow("最低收款", viewModel.hasValidQuote ? viewModel.quote.minimumReceived : "輸入數量後顯示")

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("滑價")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(String(format: "%.1f%%", viewModel.slippagePercent))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(AppTheme.primary)
                }
                Slider(value: $viewModel.slippagePercent, in: 0.1...3, step: 0.1)
                    .tint(AppTheme.primary)
                    .onChange(of: viewModel.slippagePercent) { _, _ in
                        viewModel.onTokenChanged()
                    }
            }

            Toggle(isOn: $viewModel.mevProtectionEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MEV 防護")
                        .font(.subheadline.weight(.semibold))
                    Text("Sepolia 演示標記（不影響鏈上路由）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AppTheme.primary)

            quoteRow("服務手續費", viewModel.hasValidQuote ? viewModel.quote.serviceFee : "—")

            if viewModel.isReferenceQuoteOnly, viewModel.hasValidQuote {
                Text("參考報價模式：可試算匯率，測試網不廣播 USDT 鏈上交易。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.primary)
            } else if let reason = viewModel.swapDisabledReason, viewModel.hasValidQuote {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(AppTheme.negative)
            } else if !viewModel.hasValidQuote {
                Text("在上方「支付」或「接收」輸入數量即可試算。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    private func quoteRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var swapButton: some View {
        let canSwap = viewModel.hasValidQuote
            && viewModel.canExecuteOnChain
            && viewModel.swapDisabledReason == nil
            && !viewModel.isSwapping

        return Button {
            Task { await beginSwapPreview() }
        } label: {
            HStack {
                if viewModel.isSwapping {
                    ProgressView().tint(.white)
                }
                Text(swapButtonTitle)
            }
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        canSwap
                            ? AnyShapeStyle(AppTheme.heroGradient)
                            : AnyShapeStyle(Color.gray.opacity(0.4))
                    )
            )
        }
        .disabled(!canSwap)
    }

    private var swapButtonTitle: String {
        if viewModel.isSwapping { return "廣播中…" }
        if viewModel.isReferenceQuoteOnly, viewModel.hasValidQuote {
            return "參考報價（測試網不廣播）"
        }
        return ChainConfig.usesTestnet ? "確認交換（Sepolia）" : "預覽交換"
    }
}

private struct OptionalSubpageNav: ViewModifier {
    let shows: Bool
    let backTitle: String

    func body(content: Content) -> some View {
        if shows {
            content.subpageNavigation(backTitle: backTitle)
        } else {
            content
        }
    }
}

#Preview {
    NavigationStack {
        SwapView(
            preselectedTo: MockMarketDataService().allTokens().first!,
            showsSubpageNavigation: true
        )
    }
}
