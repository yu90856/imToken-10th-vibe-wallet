import SwiftUI

struct PufferStakingView: View {
    @Environment(WalletSession.self) private var walletSession
    @Environment(\.colorScheme) private var colorScheme

    @State private var viewModel = PufferStakingViewModel()
    @State private var showPIN = false
    @State private var showWalletPassword = false
    @State private var showNeedWallet = false
    @State private var pendingTx: PendingPufferTx?
    @State private var alertMessage: String?
    @State private var alertExplorerURL: URL?
    @State private var alertOffersRetry = false
    @State private var isSubmittingTransaction = false
    @State private var showCancelPendingConfirm = false

    private enum PendingPufferTx {
        case stake
        case unstake
        case cancelPending
    }

    private enum StakingMode: String, CaseIterable, Identifiable {
        case stake
        case unstake

        var id: String { rawValue }

        var label: String {
            switch self {
            case .stake: return "質押"
            case .unstake: return "解質押"
            }
        }
    }

    @State private var stakingMode: StakingMode = .stake

    var body: some View {
        VStack(spacing: 0) {
            if let last = viewModel.lastUnstakeMessage {
                resultCard(last, isUnstake: true)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            } else if let last = viewModel.lastStakeMessage {
                resultCard(last, isUnstake: false)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    if viewModel.hasStuckPendingNonce {
                        pendingNonceBanner
                    }
                    if !PufferDemoConfig.hasOnChainVault || !viewModel.vaultReady {
                        vaultSetupCard
                    }
                    rateCard
                    unifiVaultCard
                    balanceCard
                    stakingModePicker
                    if stakingMode == .stake {
                        apyCard
                        stakeCard
                    } else {
                        unstakeCard
                    }
                    safetyCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .walletDeckScrollInset()
        }
        .background {
            AppTheme.pageBackground(for: colorScheme)
                .ignoresSafeArea(edges: [.top, .horizontal])
        }
        .navigationTitle("Puffer 質押／解質押")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: walletSession.account?.address) {
            await viewModel.refresh(walletAddress: walletSession.account?.address)
        }
        .refreshable {
            await viewModel.refresh(walletAddress: walletSession.account?.address)
        }
        .sheet(isPresented: $showPIN) {
            TransactionPINEntrySheet(mode: .verify) { success in
                showPIN = false
                if success { continueAfterTxAuth() }
            }
        }
        .sheet(isPresented: $showWalletPassword) {
            WalletPasswordSheet(
                onUnlocked: {
                    showWalletPassword = false
                    Task { await performPendingTransaction() }
                },
                onCancel: { showWalletPassword = false }
            )
        }
        .alert("Puffer 質押", isPresented: Binding(
            get: { alertMessage != nil },
            set: {
                if !$0 {
                    alertMessage = nil
                    alertExplorerURL = nil
                    alertOffersRetry = false
                }
            }
        )) {
            if let url = alertExplorerURL {
                Button("在 Etherscan 查看") {
                    UIApplication.shared.open(url)
                }
            }
            if alertOffersRetry {
                Button("再試一次") {
                    Task { await performPendingTransaction() }
                }
            }
            Button("了解", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .alert("請先建立錢包", isPresented: $showNeedWallet) {
            Button("了解", role: .cancel) {}
        } message: {
            Text("建立或匯入錢包後，才能在 Sepolia 測試 Puffer 質押。")
        }
        .confirmationDialog(
            "清除待確認交易",
            isPresented: $showCancelPendingConfirm,
            titleVisibility: .visible
        ) {
            Button("清除 Pending（消耗 Gas）", role: .destructive) {
                beginTransaction(.cancelPending, reason: "確認清除 Sepolia 待確認交易")
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(
                """
                將對簽名地址送出 0 ETH 給自己並提高 Gas，取代約 \(viewModel.pendingNonceCount) 筆待確認交易。
                每筆約需少量 Sepolia ETH，請確保餘額足夠。
                """
            )
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SketchIcon(kind: .chart, size: 20, color: AppTheme.primary)
                Text("Puffer · Sepolia 演示")
                    .notebookHeadline(18)
            }
            Text("真實 Sepolia 交易至 Vibe 演示 Vault（非官方 PufferVault；官方 SDK 質押需 Holesky）。鑄造的 pufETH 為演示代幣，可於 Etherscan 查詢。")
                .notebookCaption(12)
                .foregroundStyle(AppTheme.ink.opacity(0.65))
        }
        .padding(16)
        .glassCard(cornerRadius: 16, variant: .mint)
    }

    private var vaultSetupCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("需要 Sepolia 合約")
                .notebookHeadline(15)
                .foregroundStyle(AppTheme.warning)
            Text(PufferDemoConfig.vaultSetupHint)
                .notebookCaption(11)
                .foregroundStyle(AppTheme.ink.opacity(0.75))
            if PufferDemoConfig.hasOnChainVault {
                Text("已配置：\(viewModel.vaultAddress)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                Text(viewModel.vaultReady ? "合約已就緒" : "鏈上尚無合約代碼，請確認部署網路為 Sepolia")
                    .notebookCaption(12)
                    .foregroundStyle(viewModel.vaultReady ? AppTheme.positive : AppTheme.negative)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 14, variant: .pink)
    }

    private var rateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("匯率（參考）")
                .notebookHeadline(16)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("1 ETH ≈")
                        .notebookCaption(12)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.format(viewModel.exchangeRate.pufEthPerEth)) \(PufferDemoConfig.pufETHSymbol)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("1 pufETH ≈")
                        .notebookCaption(12)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.format(viewModel.exchangeRate.ethPerPufEth)) ETH")
                        .font(.subheadline.weight(.semibold))
                }
            }
            Text(viewModel.rateSource)
                .notebookCaption(11)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    private var unifiVaultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SketchIcon(kind: .explore, size: 18, color: AppTheme.primary)
                Text("UniFi Vault 機會")
                    .notebookHeadline(16)
                Text("即將推出")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppTheme.primary.opacity(0.12)))
                    .foregroundStyle(AppTheme.primary)
            }
            Text("質押 pufETH 後可進一步參與 Puffer UniFi Vault 策略（收益再質押、流動性等）。本 App Sepolia 演示先完成鑄造 pufETH；Vault 策略接入規劃中。")
                .notebookCaption(12)
                .foregroundStyle(AppTheme.ink.opacity(0.65))
            if let url = URL(string: PufferDemoConfig.unifiVaultInfoURL) {
                Link(destination: url) {
                    HStack {
                        Text("了解 Puffer UniFi Vault")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("→")
                    }
                    .foregroundStyle(AppTheme.primary)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(AppTheme.primary.opacity(0.35), lineWidth: 1)
                    )
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16, variant: .pink)
    }

    private var apyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("預估收益（演示）")
                .notebookHeadline(16)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("預估 APY")
                        .notebookCaption(12)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f%%", viewModel.estimatedAPYPercent))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.positive)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("持倉年化約")
                        .notebookCaption(12)
                        .foregroundStyle(.secondary)
                    Text("≈ \(viewModel.format(viewModel.estimatedAnnualYieldETH, maxFraction: 4)) ETH")
                        .font(.subheadline.weight(.semibold))
                }
            }
            Text("本次質押 \(viewModel.stakeAmountText) ETH · 預估年收益 ≈ \(viewModel.format(viewModel.estimatedStakeYieldPufETH, maxFraction: 6)) \(PufferDemoConfig.pufETHSymbol)")
                .notebookCaption(11)
                .foregroundStyle(AppTheme.ink.opacity(0.65))
            Text("僅供 Sepolia 演示參考，非實際鏈上 APY 承諾。")
                .notebookCaption(10)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .glassCard(cornerRadius: 16, variant: .mint)
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("我的餘額（鏈上）")
                .notebookHeadline(16)
            HStack {
                balanceRow(title: "Sepolia ETH", value: viewModel.format(viewModel.ethBalance, maxFraction: 4))
                Spacer()
                balanceRow(
                    title: PufferDemoConfig.pufETHSymbol,
                    value: viewModel.format(viewModel.pufETHBalance, maxFraction: 6),
                    emphasized: viewModel.pufETHBalance > 0
                )
            }
            if let reason = viewModel.stakeDisabledReason, !viewModel.canStake {
                Text(reason)
                    .notebookCaption(12)
                    .foregroundStyle(AppTheme.negative)
            }
            if viewModel.needsSepoliaFaucet {
                GoogleSepoliaFaucetButton(
                    address: walletSession.account?.address,
                    title: "用 Google 帳號領水"
                )
            }
            if let address = walletSession.account?.address {
                Text("簽名地址 · \(address)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("質押會使用此地址在 Sepolia 簽名；領水請對同一地址")
                    .notebookCaption(10)
                    .foregroundStyle(AppTheme.ink.opacity(0.55))
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16, variant: .yellow)
    }

    private var stakingModePicker: some View {
        HStack(spacing: 8) {
            ForEach(StakingMode.allCases) { mode in
                let active = mode == stakingMode
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        stakingMode = mode
                        if mode == .unstake {
                            viewModel.useFullPufETHBalanceForUnstake()
                        }
                    }
                } label: {
                    Text(mode.label)
                        .font(.subheadline.weight(active ? .semibold : .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .strokeBorder(
                                    active ? AppTheme.primary : AppTheme.cardStroke(for: colorScheme),
                                    lineWidth: 1.5
                                )
                                .background(
                                    Capsule().fill(active ? AppTheme.stickyNoteFill(for: colorScheme) : .clear)
                                )
                        )
                        .foregroundStyle(active ? AppTheme.ink : AppTheme.ink.opacity(0.65))
                        .rotationEffect(.degrees(active ? -1 : 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .glassCard(cornerRadius: 14)
    }

    private func balanceRow(title: String, value: String, emphasized: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .notebookCaption(12)
                .foregroundStyle(.secondary)
            Text(value)
                .notebookHeadline(17)
                .foregroundStyle(emphasized ? AppTheme.positive : AppTheme.ink)
        }
    }

    private var unstakeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("解質押 \(PufferDemoConfig.pufETHSymbol)")
                .notebookHeadline(16)

            Text("銷毀 \(PufferDemoConfig.pufETHSymbol) 並從演示 Vault 取回 Sepolia ETH。贖回數量以鏈上 Vault 匯率為準（非上方 API 參考價）。")
                .notebookCaption(12)
                .foregroundStyle(AppTheme.ink.opacity(0.65))

            TextField("解質押數量", text: $viewModel.unstakeAmountText)
                .keyboardType(.decimalPad)
                .font(NotebookFont.body(18))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.stickyNoteFill(for: colorScheme))
                )

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("預估取回：≈ \(viewModel.format(viewModel.unstakePreviewETH)) ETH")
                        .notebookCaption(12)
                        .foregroundStyle(AppTheme.ink.opacity(0.7))
                    if viewModel.pufETHBalance > 0 {
                        Text("鏈上持倉 \(viewModel.format(viewModel.pufETHBalance, maxFraction: 8)) \(PufferDemoConfig.pufETHSymbol)")
                            .notebookCaption(10)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("全部") {
                    viewModel.useFullPufETHBalanceForUnstake()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
                .disabled(viewModel.pufETHBalance <= 0)
            }

            if let reason = viewModel.unstakeDisabledReason, !viewModel.canUnstake {
                Text(reason)
                    .notebookCaption(12)
                    .foregroundStyle(viewModel.pufETHBalance <= 0 ? AppTheme.ink.opacity(0.65) : AppTheme.negative)
            }

            if let dust = viewModel.unstakeDustWarning {
                Text(dust)
                    .notebookCaption(12)
                    .foregroundStyle(AppTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: beginUnstake) {
                HStack {
                    if viewModel.isUnstaking {
                        ProgressView().tint(.white)
                    }
                    Text(viewModel.isUnstaking ? "廣播交易中…" : viewModel.unstakeSubmitLabel)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(viewModel.canUnstake ? AnyShapeStyle(AppTheme.heroGradient) : AnyShapeStyle(Color.gray.opacity(0.45)))
                )
            }
            .disabled(!viewModel.canUnstake || viewModel.isUnstaking || isSubmittingTransaction)
        }
        .padding(16)
        .glassCard(cornerRadius: 16, variant: .yellow)
    }

    private var stakeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("質押資產")
                .notebookHeadline(16)
            stakeAssetPicker

            if let hint = viewModel.stakeAssetUnavailableHint {
                Text(hint)
                    .notebookCaption(12)
                    .foregroundStyle(AppTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("質押 \(viewModel.selectedStakeAsset.displayName)")
                .notebookHeadline(15)
                .foregroundStyle(viewModel.selectedStakeAsset.isAvailableOnSepoliaDemo ? AppTheme.ink : AppTheme.ink.opacity(0.45))

            TextField("數量", text: $viewModel.stakeAmountText)
                .keyboardType(.decimalPad)
                .font(NotebookFont.body(18))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.stickyNoteFill(for: colorScheme))
                )

            if viewModel.selectedStakeAsset.isAvailableOnSepoliaDemo {
                let preview = (Decimal(string: viewModel.stakeAmountText) ?? 0) * viewModel.exchangeRate.pufEthPerEth
                Text("預估鑄造：≈ \(viewModel.format(preview)) \(PufferDemoConfig.pufETHSymbol)")
                    .notebookCaption(12)
                    .foregroundStyle(AppTheme.ink.opacity(0.7))
            }

            Button(action: beginStake) {
                HStack {
                    if viewModel.isStaking {
                        ProgressView().tint(.white)
                    }
                    Text(viewModel.isStaking ? "廣播交易中…" : stakeButtonTitle)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(viewModel.canStake ? AnyShapeStyle(AppTheme.heroGradient) : AnyShapeStyle(Color.gray.opacity(0.45)))
                )
            }
            .disabled(!viewModel.canStake || viewModel.isStaking || isSubmittingTransaction)
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    private var stakeAssetPicker: some View {
        VStack(spacing: 8) {
            ForEach(PufferStakeAsset.allCases) { asset in
                let selected = viewModel.selectedStakeAsset == asset
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedStakeAsset = asset
                    }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(asset.displayName)
                                    .font(.subheadline.weight(.semibold))
                                if !asset.isAvailableOnSepoliaDemo {
                                    Text("籌備中")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(AppTheme.warning.opacity(0.2)))
                                        .foregroundStyle(AppTheme.warning)
                                } else {
                                    Text("Sepolia 可用")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(AppTheme.positive.opacity(0.15)))
                                        .foregroundStyle(AppTheme.positive)
                                }
                            }
                            Text(asset.shortDescription)
                                .font(.caption)
                                .foregroundStyle(AppTheme.ink.opacity(0.55))
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(selected ? AppTheme.primary : AppTheme.ink.opacity(0.3))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selected ? AppTheme.stickyNoteFill(for: colorScheme) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                selected ? AppTheme.primary : AppTheme.cardStroke(for: colorScheme),
                                lineWidth: selected ? 1.5 : 1
                            )
                    )
                    .foregroundStyle(AppTheme.ink)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var stakeButtonTitle: String {
        if !viewModel.selectedStakeAsset.isAvailableOnSepoliaDemo {
            return "\(viewModel.selectedStakeAsset.displayName) 主網路徑籌備中"
        }
        return "確認質押 \(viewModel.selectedStakeAsset.displayName)（Sepolia）"
    }

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                SketchIcon(kind: .shield, size: 16, color: AppTheme.warning)
                Text("安全參與提示")
                    .notebookHeadline(15)
            }
            Text("• 僅 Sepolia 測試 ETH 可直接質押；stETH / wstETH 為主網路徑預告\n• 解質押需 Vault 含 withdraw 函式（請用最新合約重新部署）\n• 需足夠 ETH 支付 Gas（預留 \(viewModel.format(PufferDemoConfig.gasReserveEther)) ETH）\n• 匯率來自 Puffer API，鏈上鑄造／贖回以演示 Vault 為準\n• 鑄造 pufETH 後可關注 UniFi Vault 策略（見上方卡片）")
                .notebookCaption(12)
                .foregroundStyle(AppTheme.ink.opacity(0.7))
        }
        .padding(14)
        .glassCard(cornerRadius: 14, variant: .pink)
    }

    private func resultCard(_ message: String, isUnstake: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("上次結果")
                .notebookHeadline(15)
            Text(message)
                .notebookBody(14)
                .foregroundStyle(isUnstake && viewModel.lastUnstakeWasDust ? AppTheme.warning : AppTheme.positive)
                .fixedSize(horizontal: false, vertical: true)
            if let hash = viewModel.lastTxHash,
               let url = URL(string: "\(ChainConfig.active.explorerURL)/tx/\(hash)") {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Text("在 Sepolia Etherscan 查看")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.primary)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 14, variant: .mint)
        .shadow(color: AppTheme.ink.opacity(0.08), radius: 6, y: 2)
    }

    private func beginStake() {
        beginTransaction(.stake, reason: "確認 Puffer Sepolia 鏈上質押")
    }

    private func beginUnstake() {
        beginTransaction(.unstake, reason: "確認 Puffer Sepolia 解質押")
    }

    private var pendingNonceBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.warning)
                Text("待確認交易 \(viewModel.pendingNonceCount) 筆")
                    .notebookHeadline(15)
                    .foregroundStyle(AppTheme.ink)
            }
            Text(viewModel.unstakeDisabledReason ?? "請在 Etherscan 處理 Pending 後再演示質押／解質押。")
                .notebookCaption(12)
                .foregroundStyle(AppTheme.ink.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            if let url = viewModel.signingAddressExplorerURL {
                Button {
                    UIApplication.shared.open(url)
                } label: {
                    Label("打開 Sepolia Etherscan", systemImage: "arrow.up.right.square")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(AppTheme.primary)
            }
            Button {
                showCancelPendingConfirm = true
            } label: {
                HStack {
                    if viewModel.isCancellingPending {
                        ProgressView().tint(.white)
                    }
                    Text(viewModel.isCancellingPending ? "清除中…" : "清除 Pending（取消待確認）")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(viewModel.isCancellingPending ? Color.gray : AppTheme.primary)
                )
            }
            .disabled(viewModel.isCancellingPending || isSubmittingTransaction)
        }
        .padding(14)
        .glassCard(cornerRadius: 14, variant: .yellow)
    }

    private func beginTransaction(_ kind: PendingPufferTx, reason: String) {
        guard walletSession.hasWallet, walletSession.account != nil else {
            showNeedWallet = true
            return
        }
        pendingTx = kind
        Task { @MainActor in
            await viewModel.refresh(walletAddress: walletSession.account?.address)
            if kind != .cancelPending, viewModel.hasStuckPendingNonce {
                presentTransactionError(PufferStakeError.stuckPendingNonce(
                    signingAddress: viewModel.signingAddressForMonitor,
                    count: viewModel.pendingNonceCount
                ))
                return
            }
            if kind == .cancelPending, !viewModel.hasStuckPendingNonce {
                alertMessage = PendingNonceCancelError.nothingToCancel.localizedDescription
                return
            }
            do {
                switch try await SigningUnlockCoordinator.prepareForSigning(reason: reason) {
                case .readyToSign:
                    await performPendingTransaction()
                case .needWalletPassword:
                    showWalletPassword = true
                }
            } catch TransactionAuthError.pinRequired {
                showPIN = true
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
    private func continueAfterTxAuth() {
        Task {
            switch try? await SigningUnlockCoordinator.prepareForSigning(reason: "解鎖以簽署 Sepolia 交易") {
            case .readyToSign:
                await performPendingTransaction()
            case .needWalletPassword, .none:
                showWalletPassword = true
            }
        }
    }

    @MainActor
    private func performPendingTransaction() async {
        guard !isSubmittingTransaction else { return }
        guard let address = walletSession.account?.address,
              let password = walletSession.signingPassword else {
            showWalletPassword = true
            return
        }
        isSubmittingTransaction = true
        alertMessage = nil
        defer { isSubmittingTransaction = false }
        do {
            switch pendingTx ?? .stake {
            case .stake:
                _ = try await viewModel.stake(walletAddress: address, walletPassword: password)
            case .unstake:
                _ = try await viewModel.unstake(walletAddress: address, walletPassword: password)
            case .cancelPending:
                let result = try await viewModel.cancelPendingNonces(
                    walletAddress: address,
                    walletPassword: password
                )
                alertMessage = "已清除 \(result.clearedCount) 筆待確認交易，可繼續質押／解質押。"
                alertExplorerURL = viewModel.signingAddressExplorerURL
                alertOffersRetry = false
                return
            }
        } catch {
            presentTransactionError(error)
        }
    }

    @MainActor
    private func presentTransactionError(_ error: Error) {
        if let stakeError = error as? PufferStakeError {
            alertExplorerURL = stakeError.explorerAddressURL
            alertOffersRetry = stakeError.explorerAddressURL != nil
        } else {
            alertExplorerURL = nil
            alertOffersRetry = false
        }
        alertMessage = error.localizedDescription
    }
}

#Preview {
    NavigationStack {
        PufferStakingView()
            .environment(WalletSession.shared)
    }
}
