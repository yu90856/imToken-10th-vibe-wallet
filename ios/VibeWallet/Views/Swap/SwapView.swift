import SwiftUI

struct SwapView: View {
    @State private var viewModel: SwapViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var pickerTarget: TokenPickerTarget?
    @State private var showSwapConfirm = false
    @State private var showPINAuth = false
    @State private var showPinNotSetAlert = false
    @State private var authErrorMessage: String?
    private let showsSubpageNavigation: Bool

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
        self.showsSubpageNavigation = showsSubpageNavigation
        _viewModel = State(initialValue: SwapViewModel(preselectedTo: preselectedTo))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                swapCard
                quoteSection
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
                    ? viewModel.walletTokens
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
        .alert("確認交換", isPresented: $showSwapConfirm) {
            Button("取消", role: .cancel) {}
            Button("我了解，繼續（示範）") {}
        } message: {
            Text("此為 Mock 流程，不會廣播鏈上交易。正式版需你親自確認簽名。")
        }
    }

    @MainActor
    private func beginSwapPreview() async {
        do {
            try await TransactionAuthService.authenticateForTransaction(
                reason: "確認預覽此筆交換"
            )
            showSwapConfirm = true
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
                    set: onAmountChange
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
                    Text("降低被夾擊風險（示範開關）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AppTheme.primary)

            quoteRow("服務手續費", viewModel.hasValidQuote ? viewModel.quote.serviceFee : "—")

            if !viewModel.hasValidQuote {
                Text("在上方「支付」或「接收」任一侧輸入數量即可試算。")
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
        Button {
            Task { await beginSwapPreview() }
        } label: {
            Text("預覽交換")
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            viewModel.hasValidQuote
                                ? AnyShapeStyle(AppTheme.heroGradient)
                                : AnyShapeStyle(Color.gray.opacity(0.4))
                        )
                )
        }
        .disabled(!viewModel.hasValidQuote)
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
