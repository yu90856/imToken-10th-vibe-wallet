import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    private(set) var portfolio: PortfolioSummary
    private(set) var sovereignty: SovereigntyStatus
    private(set) var holdings: [HoldingAsset]
    var toastMessage: String?

    private(set) var shoppingWishlist: [HomeShoppingWishlistRow] = []
    private(set) var shoppingStickyBanner: String?
    private(set) var shoppingWishlistLoading = false

    private var weatherService: HomeWeatherService?
    private(set) var refreshSpinDegrees: Double = 0

    private let mockData: HomeDataProviding
    private var balanceStore: WalletBalanceStore?

    init(dataService: HomeDataProviding = MockHomeDataService()) {
        self.mockData = dataService
        sovereignty = dataService.loadSovereigntyStatus()
        portfolio = dataService.loadPortfolio(refreshOffset: 0)
        holdings = dataService.loadHoldings()
    }

    func attachSharedServices() {
        if weatherService == nil {
            weatherService = HomeWeatherService.shared
        }
        guard balanceStore == nil else { return }
        let store = WalletBalanceStore.shared
        balanceStore = store
        applyCachedBalances()
    }

    private var resolvedBalanceStore: WalletBalanceStore {
        if let balanceStore { return balanceStore }
        let store = WalletBalanceStore.shared
        balanceStore = store
        return store
    }

    private var resolvedWeatherService: HomeWeatherService {
        if let weatherService { return weatherService }
        let service = HomeWeatherService.shared
        weatherService = service
        return service
    }

    private var shouldUseChainBalances: Bool {
        ChainConfig.usesTestnet && WalletSession.shared.hasWallet
    }

    func applyCachedBalances() {
        guard let snap = resolvedBalanceStore.snapshot else { return }
        portfolio = snap.portfolio
        holdings = snap.holdings
    }

    var formattedDateLine: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "yyyy年MM月dd日，天氣："
        return formatter.string(from: Date())
    }

    var headerDateWeatherLine: String {
        formattedDateLine + resolvedWeatherService.weatherLine
    }

    var topHoldingsByValue: [HoldingAsset] {
        holdings
            .sorted { $0.valueUSD > $1.valueUSD }
            .prefix(2)
            .map { $0 }
    }

    func refreshWeatherLine() {
        resolvedWeatherService.refreshIfNeeded()
    }

    func refresh() {
        refreshSpinDegrees += 360
        sovereignty = mockData.loadSovereigntyStatus()
        Task {
            await loadChainBalances(force: true)
            await refreshShoppingWishlist()
        }
    }

    func refreshShoppingWishlist() async {
        shoppingWishlistLoading = true
        defer { shoppingWishlistLoading = false }

        let granted = await ShoppingRemindersService.requestAccessIfNeeded()
        guard granted else {
            shoppingStickyBanner = ShoppingRemindersError.accessDenied.errorDescription
            shoppingWishlist = []
            return
        }

        let reminders: [ShoppingReminderItem]
        do {
            reminders = try await ShoppingRemindersService.fetchIncompleteItems()
        } catch let error as ShoppingRemindersError {
            shoppingStickyBanner = error.errorDescription
            shoppingWishlist = []
            return
        } catch {
            shoppingStickyBanner = "無法讀取提醒事項：\(error.localizedDescription)"
            shoppingWishlist = []
            return
        }

        if reminders.isEmpty {
            shoppingStickyBanner = nil
            shoppingWishlist = []
            return
        }

        var rows: [HomeShoppingWishlistRow] = []
        var apiHint: String?

        for reminder in reminders.prefix(3) {
            let query = reminder.searchQuery
            switch await BitrefillCatalogService.search(query: query, limit: 5) {
            case .success(let products):
                let status: String
                if products.first != nil {
                    status = products.count > 1
                        ? "Bitrefill 找到 \(products.count) 項商品"
                        : "Bitrefill 可購買"
                } else {
                    status = "Bitrefill 暫無相符商品"
                }
                rows.append(
                    HomeShoppingWishlistRow(
                        id: reminder.id,
                        reminderTitle: reminder.title,
                        statusLine: status,
                        topProductName: products.first.map { "\($0.name) · \($0.countryName)" },
                        searchQuery: query,
                        previewProducts: products
                    )
                )
            case .failure(let error):
                if case .missingAPIKey = error {
                    if apiHint == nil {
                        apiHint = bitrefillSecretsHint
                    }
                    rows.append(
                        HomeShoppingWishlistRow(
                            id: reminder.id,
                            reminderTitle: reminder.title,
                            statusLine: "待辦已同步 · Bitrefill API 未就緒",
                            topProductName: nil,
                            searchQuery: query,
                            previewProducts: []
                        )
                    )
                } else {
                    rows.append(
                        HomeShoppingWishlistRow(
                            id: reminder.id,
                            reminderTitle: reminder.title,
                            statusLine: error.localizedDescription,
                            topProductName: nil,
                            searchQuery: query,
                            previewProducts: []
                        )
                    )
                }
            }
        }

        shoppingWishlist = rows
        shoppingStickyBanner = apiHint
        await WidgetSyncService.refreshFromApp()
    }

    func loadChainBalancesIfNeeded() {
        Task { await loadChainBalances(force: false) }
    }

    func reloadAfterWalletActivity() {
        applyCachedBalances()
        Task { await loadChainBalances(force: true) }
    }

    @MainActor
    private func loadChainBalances(force: Bool) async {
        guard shouldUseChainBalances else {
            portfolio = mockData.loadPortfolio(refreshOffset: 0)
            holdings = mockData.loadHoldings()
            return
        }

        await resolvedBalanceStore.refresh(force: force)
        if let snap = resolvedBalanceStore.snapshot {
            portfolio = snap.portfolio
            holdings = snap.holdings
            if force {
                toastMessage = "測試網餘額已更新 · \(formattedTime())"
            }
        } else if resolvedBalanceStore.lastError != nil, !resolvedBalanceStore.hasDisplayableSnapshot {
            toastMessage = "讀取測試網失敗：\(resolvedBalanceStore.lastError ?? "")"
        }
    }

    func dismissToast() {
        toastMessage = nil
    }

    private func formattedTime() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }

    private var bitrefillSecretsHint: String {
        if SecretsReader.hasBitrefillAPIKey {
            return "Bitrefill API 金鑰已載入；若仍失敗請點重新整理。"
        }
        return "請確認 ios/VibeWallet/Config/Secrets.plist 含 BITREFILL_API_KEY，並在 Xcode 重新 Run（Build Phase 會複製 Secrets）。"
    }

}
