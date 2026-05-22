import SwiftUI

struct WalletView: View {
    @State private var viewModel = AssetsViewModel()
    @Environment(WalletSession.self) private var walletSession
    @Environment(\.colorScheme) private var colorScheme
    @State private var path = NavigationPath()
    @State private var copiedAddress = false
    @State private var showSend = false
    @State private var showReceive = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    totalCard
                    holdingsSection
                    if ChainConfig.usesTestnet {
                        faucetSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .walletDeckScrollInset()
            .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle("錢包")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.balanceHidden.toggle()
                    } label: {
                        SketchIcon(kind: .eye, size: 22, color: AppTheme.primary)
                    }
                    .accessibilityLabel(viewModel.balanceHidden ? "顯示餘額" : "隱藏餘額")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: viewModel.refresh) {
                        SketchIcon(kind: .refresh, size: 22, color: AppTheme.primary)
                    }
                }
            }
            .navigationDestination(for: WalletRoute.self) { route in
                switch route {
                case .tokenHistory(let tokenId):
                    if let holding = viewModel.holding(id: tokenId) {
                        TokenTransactionHistoryView(holding: holding)
                    } else {
                        Text("找不到此代幣")
                            .notebookBody(15)
                    }
                }
            }
            .onAppear {
                viewModel.attachSharedBalanceStore()
                viewModel.applyCachedBalances()
                viewModel.loadFromChainIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: .walletBalancesDidChange)) { _ in
                viewModel.reloadAfterWalletActivity()
            }
            .task(id: walletSession.account?.address) {
                viewModel.attachSharedBalanceStore()
                viewModel.applyCachedBalances()
                viewModel.loadFromChainIfNeeded()
            }
            .sheet(isPresented: $showSend) {
                WalletTransferSheet(mode: .send, holdings: viewModel.holdings, isDecoy: false)
            }
            .sheet(isPresented: $showReceive) {
                WalletTransferSheet(mode: .receive, holdings: viewModel.holdings, isDecoy: false)
            }
            .vibeNavigationPathAnimation(path)
        }
    }

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    SketchIcon(kind: .chart, size: 18, color: AppTheme.ink.opacity(0.55))
                    Text("總資產")
                        .notebookHeadline(17)
                }
                .foregroundStyle(AppTheme.ink.opacity(0.7))
                Spacer()
                BNBChainBadge(compact: true)
            }

            Text(viewModel.displayedTotal)
                .font(NotebookFont.largeAmount(36))
                .foregroundStyle(AppTheme.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            HStack(spacing: 8) {
                Text("24h")
                    .notebookCaption(11)
                    .foregroundStyle(AppTheme.ink.opacity(0.45))
                Text(viewModel.displayedChange)
                    .notebookBody(14)
                    .foregroundStyle(
                        viewModel.portfolio.change24hPercent >= 0
                            ? AppTheme.positive
                            : AppTheme.negative
                    )
            }

            HStack(spacing: 10) {
                walletActionButton(title: "發送", icon: "arrow.up.right") { showSend = true }
                walletActionButton(title: "接收", icon: "arrow.down.left") { showReceive = true }
            }
            .padding(.top, 4)

            if let account = walletSession.account {
                Divider().opacity(0.35)
                HStack {
                    Text(account.shortAddress)
                        .font(NotebookFont.caption(11))
                        .monospaced()
                        .foregroundStyle(AppTheme.ink.opacity(0.5))
                    Spacer()
                    Button {
                        UIPasteboard.general.string = account.address
                        copiedAddress = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copiedAddress = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            SketchIcon(kind: .copy, size: 14, color: AppTheme.primary)
                            Text(copiedAddress ? "已複製" : "複製")
                                .notebookCaption(11)
                        }
                    }
                    .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 16, variant: .yellow, tilt: 0.5)
    }

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("我的代幣")
                .notebookHeadline(17)
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, 4)

            if viewModel.holdings.isEmpty {
                Text("尚無持倉")
                    .notebookBody(14)
                    .foregroundStyle(AppTheme.ink.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .glassCard(cornerRadius: 14, variant: .mint)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.holdings) { holding in
                        Button {
                            path.append(WalletRoute.tokenHistory(holding.id))
                        } label: {
                            holdingRow(holding)
                        }
                        .buttonStyle(VibeCardPressStyle())
                    }
                }
            }
        }
    }

    private func holdingRow(_ holding: HoldingAsset) -> some View {
        HStack(spacing: 14) {
            TokenLogoView(tokenId: holding.id, symbol: holding.symbol, imageURL: holding.imageURL, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(holding.name)
                    .notebookHeadline(16)
                    .foregroundStyle(AppTheme.ink)
                Text("\(holding.balance) \(holding.symbol)")
                    .notebookCaption(12)
                    .foregroundStyle(AppTheme.ink.opacity(0.55))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(viewModel.balanceHidden ? "••••" : holding.formattedValue)
                    .notebookHeadline(15)
                    .foregroundStyle(AppTheme.ink)
                HStack(spacing: 4) {
                    Text("交易紀錄")
                        .notebookCaption(11)
                    Text("→")
                        .notebookCaption(12)
                }
                .foregroundStyle(AppTheme.primary)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 16, variant: .pink, tilt: -0.5)
    }

    private func walletActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                Text(title)
                    .notebookHeadline(15)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(AppTheme.primary)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(AppTheme.primary.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var faucetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("測試網領水")
                .notebookHeadline(17)
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, 4)
            TestnetBanner(address: walletSession.account?.address)
        }
    }
}

#Preview {
    WalletView()
        .environment(WalletSession.shared)
}
