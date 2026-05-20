import Foundation

struct MockMarketDataService {
    func allTokens() -> [MarketToken] {
        ethTokens()
    }

    func walletSwappableTokens() -> [MarketToken] {
        ethTokens().filter { $0.walletBalance != nil && ($0.walletBalance ?? 0) > 0 }
    }

    func token(id: String) -> MarketToken? {
        ethTokens().first { $0.id == id }
    }

    func buildQuote(
        from: MarketToken,
        to: MarketToken,
        amountIn: Decimal,
        slippagePercent: Double,
        mevProtectionEnabled: Bool
    ) -> SwapQuote? {
        guard amountIn > 0, from.priceUSD > 0, to.priceUSD > 0 else { return nil }
        let feeMultiplier = Decimal(string: "0.997")!
        let usd = amountIn * from.priceUSD
        let out = (usd / to.priceUSD) * feeMultiplier
        let minOut = out * (1 - Decimal(slippagePercent / 100))
        let rate = out / amountIn

        let rateFormatter = NumberFormatter()
        rateFormatter.maximumFractionDigits = 6
        let rateText = "1 \(from.symbol) ≈ \(rateFormatter.string(from: rate as NSDecimalNumber) ?? "—") \(to.symbol)"

        let amountFormatter = NumberFormatter()
        amountFormatter.maximumFractionDigits = 8
        let minText = "\(amountFormatter.string(from: minOut as NSDecimalNumber) ?? "0") \(to.symbol)"

        let route = mevProtectionEnabled
            ? "\(from.symbol) → \(to.symbol) · Uniswap V3 · Sepolia"
            : "\(from.symbol) → \(to.symbol) · Uniswap V3"

        return SwapQuote(
            routeDescription: route,
            exchangeRate: rateText,
            minimumReceived: minText,
            serviceFee: "0.3%",
            slippagePercent: slippagePercent,
            mevProtectionEnabled: mevProtectionEnabled
        )
    }

    private func ethTokens() -> [MarketToken] {
        [
            MarketToken(
                id: "eth",
                symbol: "ETH",
                name: "Ethereum",
                contractAddress: "0x0000000000000000000000000000000000000000",
                priceUSD: 3_000,
                change24hPercent: 1.5,
                volume24hUSD: 12_000_000_000,
                category: .mainstream,
                walletBalance: 0.42,
                imageURL: TokenLogoCatalog.url(for: "eth")?.absoluteString
            ),
            MarketToken(
                id: "usdc",
                symbol: "USDC",
                name: "USD Coin",
                contractAddress: "0x1c7D4B196Cb0C7B19694695c6190F8A4a4a4a4a4",
                priceUSD: 1,
                change24hPercent: 0.01,
                volume24hUSD: 2_000_000_000,
                category: .mainstream,
                walletBalance: 120,
                imageURL: TokenLogoCatalog.url(for: "usdc")?.absoluteString
            ),
            MarketToken(
                id: "weth",
                symbol: "WETH",
                name: "Wrapped Ether",
                contractAddress: "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9",
                priceUSD: 3_000,
                change24hPercent: 1.4,
                volume24hUSD: 800_000_000,
                category: .mainstream,
                walletBalance: nil,
                imageURL: TokenLogoCatalog.url(for: "weth")?.absoluteString
            ),
            MarketToken(
                id: "link",
                symbol: "LINK",
                name: "Chainlink",
                contractAddress: "0x779877A7B0D9E8603169Ddb44Eb52e8e0d1c1c1c",
                priceUSD: 14.5,
                change24hPercent: -0.8,
                volume24hUSD: 400_000_000,
                category: .onChain,
                walletBalance: nil,
                imageURL: TokenLogoCatalog.url(for: "link")?.absoluteString
            ),
        ]
    }
}
