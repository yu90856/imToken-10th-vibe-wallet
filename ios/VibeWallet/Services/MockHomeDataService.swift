import Foundation

/// Hardcoded demo data for UI development. No key material or network calls.
protocol HomeDataProviding {
    func loadPortfolio(refreshOffset: Int) -> PortfolioSummary
    func loadSovereigntyStatus() -> SovereigntyStatus
    func loadHoldings() -> [HoldingAsset]
}

struct MockHomeDataService: HomeDataProviding {
    func loadPortfolio(refreshOffset: Int = 0) -> PortfolioSummary {
        let jitter = Decimal(refreshOffset % 5) * 47.2
        let base: Decimal = 1_280.55
        let delta = Double((refreshOffset % 3) - 1) * 0.22
        return PortfolioSummary(
            totalBalanceUSD: base + jitter,
            change24hPercent: 1.12 + delta,
            change24hUSD: 48.2 + jitter,
            lastUpdated: Date(),
            currencyCode: "USD"
        )
    }

    func loadHoldings() -> [HoldingAsset] {
        [
            HoldingAsset(
                id: "eth",
                symbol: "ETH",
                name: "Ethereum",
                balance: "0.42",
                valueUSD: 1_260,
                change24hPercent: 1.2,
                imageURL: TokenLogoCatalog.url(for: "eth")?.absoluteString
            ),
            HoldingAsset(
                id: "usdc",
                symbol: "USDC",
                name: "USD Coin",
                balance: "120",
                valueUSD: 120,
                change24hPercent: 0.01,
                imageURL: TokenLogoCatalog.url(for: "usdc")?.absoluteString
            ),
        ]
    }

    func loadSovereigntyStatus() -> SovereigntyStatus {
        SovereigntyStatus(
            biometric: .active,
            backupGuardian: .partial,
            defenseScore: 78,
            lastVerified: Date().addingTimeInterval(-3600)
        )
    }
}
