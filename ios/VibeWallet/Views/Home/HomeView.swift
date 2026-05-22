import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @Bindable private var weatherService = HomeWeatherService.shared
    @Environment(WalletSession.self) private var walletSession
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appNavigation) private var appNavigation
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var appNavigation = appNavigation
        NavigationStack(path: $appNavigation.homePath) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: VibeSpacing.large) {
                    headerSection

                    assetCardSection

                    HomeShoppingStickyCard(
                        rows: viewModel.shoppingWishlist,
                        bannerMessage: viewModel.shoppingStickyBanner,
                        isLoading: viewModel.shoppingWishlistLoading,
                        onRefresh: {
                            Task { await viewModel.refreshShoppingWishlist() }
                        },
                        onOpenShop: { row in
                            appNavigation.homePath.append(
                                HomeRoute.bitrefillShop(
                                    initialQuery: row.searchQuery,
                                    previewProducts: row.previewProducts
                                )
                            )
                        }
                    )

                    HotNewsStickyCard()

                    PasskeySecureStatusView()

                    sovereigntyFootnote
                }
                .padding(.horizontal, VibeSpacing.mediumLarge)
                .padding(.top, VibeSpacing.xSmall)
                .padding(.bottom, VibeSpacing.large)
            }
            .vibeNotebookPage(colorScheme: colorScheme)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("vibe note")
                        .notebookHeadline(22)
                        .foregroundStyle(AppTheme.ink(for: colorScheme))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appNavigation.homePath.append(HomeRoute.settings)
                    } label: {
                        SketchIcon(kind: .gear, size: 22, color: AppTheme.primary)
                    }
                    .accessibilityLabel("設定")
                }
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .portfolio:
                    PortfolioDetailView(
                        portfolio: viewModel.portfolio,
                        holdings: viewModel.holdings
                    )
                    .subpageNavigation(backTitle: "首頁")
                case .pufferStaking:
                    PufferStakingView()
                        .subpageNavigation(backTitle: "首頁")
                case .bitrefillShop(let query, let previewProducts):
                    BitrefillShopView(initialQuery: query, previewProducts: previewProducts) { productId in
                        appNavigation.homePath.append(HomeRoute.bitrefillProduct(productId: productId))
                    }
                    .subpageNavigation(backTitle: "首頁")
                case .bitrefillProduct(let productId):
                    BitrefillProductDetailView(productId: productId) { invoice in
                        appNavigation.homePath.append(HomeRoute.bitrefillCheckout(invoice: invoice))
                    }
                    .subpageNavigation(backTitle: "商店")
                case .bitrefillCheckout(let invoice):
                    BitrefillCheckoutView(invoice: invoice)
                        .subpageNavigation(backTitle: "確認")
                case .sovereignty:
                    SovereigntyDetailView(status: viewModel.sovereignty)
                        .subpageNavigation(backTitle: "首頁")
                case .settings:
                    SettingsView()
                        .subpageNavigation(backTitle: "首頁")
                }
            }
            .refreshable {
                viewModel.refresh()
            }
            .overlay(alignment: .bottom) {
                if let toast = viewModel.toastMessage {
                    ToastBanner(message: toast) {
                        viewModel.dismissToast()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, WalletDeckMetrics.bottomInset + 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { viewModel.dismissToast() }
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.toastMessage)
            .vibeNavigationPathAnimation(appNavigation.homePath)
            .onAppear {
                viewModel.attachSharedServices()
                viewModel.applyCachedBalances()
                viewModel.refreshWeatherLine()
                viewModel.loadChainBalancesIfNeeded()
                Task { await viewModel.refreshShoppingWishlist() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .walletBalancesDidChange)) { _ in
                viewModel.reloadAfterWalletActivity()
            }
            .task(id: walletSession.account?.address) {
                viewModel.attachSharedServices()
                viewModel.applyCachedBalances()
                viewModel.loadChainBalancesIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    weatherService.refreshIfNeeded()
                    Task { await viewModel.refreshShoppingWishlist() }
                }
            }
        }
    }

    private var assetCardSection: some View {
        VStack(alignment: .trailing, spacing: 6) {
            ZStack {
                Button {
                    appNavigation.homePath.append(HomeRoute.portfolio)
                } label: {
                    AssetBalanceCard(
                        portfolio: viewModel.portfolio,
                        topHoldings: viewModel.topHoldingsByValue
                    )
                }
                .buttonStyle(VibeCardPressStyle())

                PufferNotebookStickerButton {
                    appNavigation.homePath.append(HomeRoute.pufferStaking)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 8)
                .zIndex(2)
            }

            HStack(spacing: 4) {
                Text("查看持倉明細")
                    .notebookCaption(12)
                Text("→")
                    .notebookCaption(14)
            }
            .foregroundStyle(AppTheme.primary)
        }
    }

    private func tappableCard<Content: View>(
        route: HomeRoute,
        hint: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button {
            appNavigation.homePath.append(route)
        } label: {
            VStack(alignment: .trailing, spacing: 6) {
                content()
                HStack(spacing: 4) {
                    Text(hint)
                        .notebookCaption(12)
                    Text("→")
                        .notebookCaption(14)
                }
                .foregroundStyle(AppTheme.primary)
            }
        }
        .buttonStyle(VibeCardPressStyle())
        .accessibilityHint(hint)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.formattedDateLine + weatherService.weatherLine)
                .font(NotebookFont.body(15))
                .foregroundStyle(AppTheme.ink(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            HStack(spacing: 8) {
                BNBChainBadge(compact: true)
                if let account = walletSession.account {
                    Text(account.shortAddress)
                        .font(NotebookFont.caption(12))
                        .monospaced()
                        .foregroundStyle(AppTheme.secondaryInk(for: colorScheme))
                } else {
                    Text("尚未建立錢包")
                        .notebookCaption()
                        .foregroundStyle(AppTheme.secondaryInk(for: colorScheme))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var sovereigntyFootnote: some View {
        HStack(alignment: .top, spacing: 8) {
            SketchIcon(kind: .shield, size: 16, color: AppTheme.ink.opacity(0.5))
            Text(ChainConfig.usesTestnet
                ? "已連線 Sepolia；首頁餘額為鏈上 ETH。下拉可重新整理。"
                : "資產與行情為示範資料。keystore 由 Token Core 在本機處理。")
                .notebookCaption(11)
                .foregroundStyle(AppTheme.secondaryInk(for: colorScheme))
        }
        .padding(.horizontal, VibeSpacing.xxSmall)
    }

}

private struct ToastBanner: View {
    let message: String
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.positive)
            Text(message)
                .notebookBody(15)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 12, variant: .yellow, tilt: 0.4)
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}

#Preview("Light") {
    MainTabView()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    MainTabView()
        .preferredColorScheme(.dark)
}
