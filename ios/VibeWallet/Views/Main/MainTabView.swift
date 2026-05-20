import SwiftUI

enum AppTab: Hashable {
    case home
    case market
    case swap
    case explore
    case wallet
}

struct MainTabView: View {
    @State private var navigation = AppNavigationModel()
    @Bindable private var duress = DuressModeController.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(WalletSession.self) private var walletSession

    var body: some View {
        @Bindable var navigation = navigation
        ZStack {
            AppTheme.pageBackground(for: colorScheme)
                .ignoresSafeArea()

            tabContent(navigation: navigation)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            WalletDeckBar(selection: $navigation.selectedTab, onSelect: handleDeckTap)
                .padding(.horizontal, 12)
        }
        .environment(\.appNavigation, navigation)
        .overlay {
            if duress.isAppLocked {
                AppLockOverlay()
                    .transition(.opacity)
            } else if duress.fakeErrorPresented {
                DuressFakeErrorOverlay()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: duress.isAppLocked)
        .animation(.easeInOut(duration: 0.2), value: duress.fakeErrorPresented)
        .onAppear {
            if !duress.isDecoyActive {
                navigation.selectedTab = .home
            }
            lockIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                duress.markNeedsUnlockAfterBackground()
            case .active:
                lockIfNeeded()
            default:
                break
            }
        }
        .onChange(of: duress.isDecoyActive) { _, active in
            if active {
                navigation.goHome()
                navigation.selectedTab = .wallet
            }
        }
    }

    private func lockIfNeeded() {
        guard walletSession.hasWallet, duress.shouldLockOnForeground else { return }
        duress.lockForForeground()
    }

    private func handleDeckTap(_ tab: AppTab) {
        duress.registerDeckTap(tab)

        if tab == .home {
            navigation.goHome()
        } else {
            navigation.selectedTab = tab
            if tab != .swap {
                navigation.swapPreselectedToken = nil
            }
        }
    }

    @ViewBuilder
    private func tabContent(navigation: AppNavigationModel) -> some View {
        if duress.isDecoyActive {
            decoyTabContent(navigation: navigation)
        } else {
            realTabContent(navigation: navigation)
        }
    }

    @ViewBuilder
    private func realTabContent(navigation: AppNavigationModel) -> some View {
        switch navigation.selectedTab {
        case .home:
            HomeView()
        case .market:
            MarketView()
        case .swap:
            NavigationStack {
                SwapView(
                    preselectedTo: navigation.swapPreselectedToken,
                    showsSubpageNavigation: false
                )
            }
            .id(navigation.swapPreselectedToken?.id ?? "swap-default")
        case .explore:
            ExploreView()
        case .wallet:
            WalletView()
        }
    }

    @ViewBuilder
    private func decoyTabContent(navigation: AppNavigationModel) -> some View {
        switch navigation.selectedTab {
        case .wallet:
            DecoyWalletView()
        case .swap:
            DecoySwapPlaceholderView()
        case .home:
            DecoyRestrictedTabView(title: "首頁")
        case .market:
            DecoyRestrictedTabView(title: "行情")
        case .explore:
            DecoyRestrictedTabView(title: "探索")
        }
    }
}

#Preview {
    MainTabView()
        .environment(WalletSession.shared)
}
