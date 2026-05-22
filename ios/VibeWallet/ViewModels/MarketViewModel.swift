import Foundation
import Observation

@MainActor
@Observable
final class MarketViewModel {
    var searchText = ""
    var segment: MarketSegment = .mainstream
    var sortOption: MarketSortOption = .volume
    var sortAscending = false
    private(set) var watchlistIDs: Set<String> = ["ethereum", "usd-coin", "bitcoin", "pepe", "dogecoin"]
    private(set) var marketDataSource = ""
    private(set) var marketLoadHint: String?

    private let mockMarket = MockMarketDataService()
    private(set) var isLoadingMarket = false
    private var allTokens: [MarketToken] = []

    init() {
        allTokens = CoinGeckoMarketService.cachedTokens()
    }

    @MainActor
    func refreshMarket(force: Bool = false) async {
        isLoadingMarket = true
        let fetched = await CoinGeckoMarketService.refreshIfNeeded(force: force)
        allTokens = await CoinGeckoMarketService.mergeWalletBalances(into: fetched)
        marketDataSource = CoinGeckoMarketService.dataSourceLabel
        marketLoadHint = CoinGeckoMarketService.lastLoadError
        isLoadingMarket = false
        await WidgetSyncService.refreshFromApp()
    }

    var marketStatusText: String {
        let count = allTokens.count
        if count == 0 { return "載入中…" }
        if let hint = marketLoadHint, !marketDataSource.contains("即時") {
            return "\(marketDataSource) · \(count) 檔 · \(hint)"
        }
        return "\(marketDataSource) · 共 \(count) 檔"
    }

    var displayedTokens: [MarketToken] {
        var list = filteredBySegment
        list = list.filter { $0.matchesSearch(searchText) }
        return sorted(list)
    }

    var isWatchlistEmpty: Bool {
        segment == .watchlist && displayedTokens.isEmpty
    }

    func toggleWatchlist(_ token: MarketToken) {
        if watchlistIDs.contains(token.id) {
            watchlistIDs.remove(token.id)
        } else {
            watchlistIDs.insert(token.id)
        }
    }

    func isWatchlisted(_ token: MarketToken) -> Bool {
        watchlistIDs.contains(token.id)
    }

    func toggleSort(_ option: MarketSortOption) {
        if sortOption == option {
            sortAscending.toggle()
        } else {
            sortOption = option
            sortAscending = option == .name
        }
    }

    func sortLabel(for option: MarketSortOption) -> String {
        guard sortOption == option else { return option.rawValue }
        return sortAscending ? "\(option.rawValue) ↑" : "\(option.rawValue) ↓"
    }

    func buildQuote(
        from: MarketToken,
        to: MarketToken,
        amountIn: Decimal,
        slippagePercent: Double,
        mevProtectionEnabled: Bool
    ) -> SwapQuote? {
        mockMarket.buildQuote(
            from: from,
            to: to,
            amountIn: amountIn,
            slippagePercent: slippagePercent,
            mevProtectionEnabled: mevProtectionEnabled
        )
    }

    private var filteredBySegment: [MarketToken] {
        switch segment {
        case .watchlist:
            return allTokens.filter { watchlistIDs.contains($0.id) }
        case .mainstream:
            return allTokens.filter { $0.category == .mainstream }
        case .onChain:
            return allTokens.filter { $0.category == .onChain }
        }
    }

    private func sorted(_ tokens: [MarketToken]) -> [MarketToken] {
        tokens.sorted { a, b in
            let ordered: Bool
            switch sortOption {
            case .name:
                ordered = a.name.localizedCompare(b.name) == .orderedAscending
            case .volume:
                ordered = a.volume24hUSD < b.volume24hUSD
            case .change24h:
                ordered = a.change24hPercent < b.change24hPercent
            }
            return sortAscending ? ordered : !ordered
        }
    }
}
