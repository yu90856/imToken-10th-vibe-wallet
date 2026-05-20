import Foundation
import Observation

@Observable
final class HomeViewModel {
    private(set) var portfolio: PortfolioSummary
    private(set) var sovereignty: SovereigntyStatus
    private(set) var holdings: [HoldingAsset]
    private(set) var userDisplayName: String
    var toastMessage: String?

    private(set) var refreshSpinDegrees: Double = 0
    private(set) var isLoadingChainBalance = false

    private let mockData: HomeDataProviding
    private var refreshCount = 0

    init(dataService: HomeDataProviding = MockHomeDataService()) {
        self.mockData = dataService
        self.portfolio = dataService.loadPortfolio(refreshOffset: 0)
        self.sovereignty = dataService.loadSovereigntyStatus()
        self.holdings = dataService.loadHoldings()
        if let short = WalletSession.shared.account?.shortAddress {
            self.userDisplayName = short
        } else {
            self.userDisplayName = "Viola"
        }
    }

    func updateWalletDisplayName() {
        userDisplayName = WalletSession.shared.account?.shortAddress ?? "Viola"
    }

    func refresh() {
        refreshCount += 1
        refreshSpinDegrees += 360
        sovereignty = mockData.loadSovereigntyStatus()
        Task { await loadChainBalances() }
    }

    func loadChainBalancesIfNeeded() {
        Task { await loadChainBalances() }
    }

    @MainActor
    private func loadChainBalances() async {
        guard ChainConfig.usesTestnet, let address = WalletSession.shared.account?.address else {
            portfolio = mockData.loadPortfolio(refreshOffset: refreshCount)
            holdings = mockData.loadHoldings()
            return
        }

        isLoadingChainBalance = true
        defer { isLoadingChainBalance = false }

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
            holdings = [
                HoldingAsset(
                    id: "eth-native",
                    symbol: ChainConfig.active.symbol,
                    name: "\(ChainConfig.active.name) 原生幣",
                    balance: formatEther(eth),
                    valueUSD: totalUSD,
                    change24hPercent: CoinGeckoMarketService.token(id: "ethereum")?.change24hPercent ?? 0,
                    imageURL: CoinGeckoMarketService.token(id: "ethereum")?.imageURL
                        ?? TokenLogoCatalog.url(for: "eth")?.absoluteString
                ),
            ]
            toastMessage = "測試網餘額已更新 · \(formattedTime())"
        } catch {
            portfolio = mockData.loadPortfolio(refreshOffset: refreshCount)
            holdings = mockData.loadHoldings()
            toastMessage = "讀取測試網失敗：\(error.localizedDescription)"
        }
    }

    func dismissToast() {
        toastMessage = nil
    }

    private func formatEther(_ amount: Decimal) -> String {
        let n = NSDecimalNumber(decimal: amount)
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 6
        f.numberStyle = .decimal
        return f.string(from: n) ?? "\(amount)"
    }

    private func formattedTime() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "早安"
        case 12..<18: return "午安"
        default: return "晚安"
        }
    }
}
