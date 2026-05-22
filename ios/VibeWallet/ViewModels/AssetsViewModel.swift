import Foundation
import Observation

@MainActor
@Observable
final class AssetsViewModel {
    private(set) var portfolio: PortfolioSummary
    private(set) var holdings: [HoldingAsset]
    var balanceHidden = false

    private let mockData: HomeDataProviding
    /// 延後綁定，避免 `@State = AssetsViewModel()` 在非 MainActor 環境觸發 Swift 6 錯誤
    private var balanceStore: WalletBalanceStore?

    init(dataService: HomeDataProviding = MockHomeDataService()) {
        self.mockData = dataService
        portfolio = dataService.loadPortfolio(refreshOffset: 0)
        holdings = dataService.loadHoldings()
    }

    func attachSharedBalanceStore() {
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

    func applyCachedBalances() {
        guard let snap = resolvedBalanceStore.snapshot else { return }
        portfolio = snap.portfolio
        holdings = snap.holdings
    }

    func refresh() {
        Task { await loadFromChain(force: true) }
    }

    func loadFromChainIfNeeded() {
        Task { await loadFromChain(force: false) }
    }

    func reloadAfterWalletActivity() {
        applyCachedBalances()
        Task { await loadFromChain(force: true) }
    }

    private func loadFromChain(force: Bool) async {
        guard ChainConfig.usesTestnet, WalletSession.shared.hasWallet else {
            portfolio = mockData.loadPortfolio(refreshOffset: 0)
            holdings = mockData.loadHoldings()
            return
        }

        await resolvedBalanceStore.refresh(force: force)
        if let snap = resolvedBalanceStore.snapshot {
            portfolio = snap.portfolio
            holdings = snap.holdings
        }
    }

    var displayedTotal: String {
        balanceHidden ? "••••••" : portfolio.formattedTotal
    }

    var displayedChange: String {
        balanceHidden ? "••••" : portfolio.formattedChangePercent
    }

    func holding(id: String) -> HoldingAsset? {
        holdings.first { $0.id == id }
    }
}
