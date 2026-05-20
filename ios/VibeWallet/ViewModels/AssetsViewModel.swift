import Foundation
import Observation

@Observable
final class AssetsViewModel {
    private(set) var portfolio: PortfolioSummary
    private(set) var holdings: [HoldingAsset]
    var balanceHidden = false

    private let mockData: HomeDataProviding

    init(dataService: HomeDataProviding = MockHomeDataService()) {
        self.mockData = dataService
        portfolio = dataService.loadPortfolio(refreshOffset: 0)
        holdings = dataService.loadHoldings()
    }

    func refresh() {
        Task { await loadFromChain() }
    }

    func loadFromChainIfNeeded() {
        Task { await loadFromChain() }
    }

    @MainActor
    private func loadFromChain() async {
        guard ChainConfig.usesTestnet, let address = WalletSession.shared.account?.address else {
            portfolio = mockData.loadPortfolio(refreshOffset: 0)
            holdings = mockData.loadHoldings()
            return
        }

        do {
            let eth = try await ChainRPCClient.fetchNativeBalance(address: address)
            let usdRate = (try? await ChainRPCClient.fetchNativeUsdPrice()) ?? 3_000
            let totalUSD = eth * usdRate

            portfolio = PortfolioSummary(
                totalBalanceUSD: totalUSD,
                change24hPercent: 0,
                change24hUSD: 0,
                lastUpdated: Date(),
                currencyCode: "USD"
            )
            let ethMeta = CoinGeckoMarketService.token(id: "ethereum")
            holdings = [
                HoldingAsset(
                    id: "eth-native",
                    symbol: ChainConfig.active.symbol,
                    name: "\(ChainConfig.active.name) 原生幣",
                    balance: formatEther(eth),
                    valueUSD: totalUSD,
                    change24hPercent: ethMeta?.change24hPercent ?? 0,
                    imageURL: ethMeta?.imageURL
                        ?? TokenLogoCatalog.url(for: "eth")?.absoluteString
                ),
            ]
        } catch {
            portfolio = mockData.loadPortfolio(refreshOffset: 0)
            holdings = mockData.loadHoldings()
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

    private func formatEther(_ amount: Decimal) -> String {
        let n = NSDecimalNumber(decimal: amount)
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 6
        f.numberStyle = .decimal
        return f.string(from: n) ?? "\(amount)"
    }
}
