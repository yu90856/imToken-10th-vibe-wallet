import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @Environment(WalletSession.self) private var walletSession
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appNavigation) private var appNavigation

    var body: some View {
        @Bindable var appNavigation = appNavigation
        NavigationStack(path: $appNavigation.homePath) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    tappableCard(
                        route: .portfolio,
                        hint: "查看持倉明細"
                    ) {
                        AssetBalanceCard(portfolio: viewModel.portfolio)
                    }

                    HotNewsStickyCard()

                    PasskeySecureStatusView()

                    sovereigntyFootnote
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .walletDeckScrollInset()
            .background {
                AppTheme.pageBackground(for: colorScheme)
                    .ignoresSafeArea()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Vibe 筆記")
                        .notebookHeadline(22)
                        .foregroundStyle(AppTheme.ink)
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
            .onAppear {
                viewModel.updateWalletDisplayName()
                viewModel.loadChainBalancesIfNeeded()
            }
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
        .buttonStyle(CardPressStyle())
        .accessibilityHint(hint)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(viewModel.greeting)，\(viewModel.userDisplayName)")
                .notebookTitle(26)
                .foregroundStyle(AppTheme.ink)

            HStack(spacing: 8) {
                BNBChainBadge(compact: true)
                if let account = walletSession.account {
                    Text(account.shortAddress)
                        .font(NotebookFont.caption(12))
                        .monospaced()
                        .foregroundStyle(AppTheme.ink.opacity(0.55))
                } else {
                    Text("尚未建立錢包")
                        .notebookCaption()
                        .foregroundStyle(AppTheme.ink.opacity(0.55))
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
                .foregroundStyle(AppTheme.ink.opacity(0.5))
        }
        .padding(.horizontal, 4)
    }
}

private struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
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
