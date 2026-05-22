import Foundation

extension Notification.Name {
    /// 鏈上餘額變更（例如 Puffer 質押成功）— 首頁／錢包應重新讀取
    static let walletBalancesDidChange = Notification.Name("walletBalancesDidChange")
}

struct WalletOnChainSnapshot: Sendable {
    let portfolio: PortfolioSummary
    let holdings: [HoldingAsset]
}

/// 測試網錢包：Sepolia ETH + Puffer 演示 Vault 的 pufETH
@MainActor
enum WalletOnChainHoldingsService {
    private static var cachedUsdPerEth: Decimal?
    private static var cachedUsdPerEthAt: Date?
    private static let usdPriceCacheTTL: TimeInterval = 60

    static func load(address: String) async throws -> WalletOnChainSnapshot {
        let eth = try await ChainRPCClient.fetchNativeBalance(address: address)
        let pufETH = await PufferStakingService.pufETHBalance(address: address)
        let vUSDC = await SepoliaSwapService.vUSDCBalance(address: address)
        let usdPerEth = await cachedNativeUsdPrice()
        let rate = await PufferStakingService.loadExchangeRate()
        let usdcPrice = CoinGeckoMarketService.token(id: "usd-coin")?.priceUSD ?? 1

        let ethUSD = eth * usdPerEth
        let pufETHUSD = pufETH * rate.ethPerPufEth * usdPerEth
        let vUSDCUSD = vUSDC * usdcPrice
        let totalUSD = ethUSD + pufETHUSD + vUSDCUSD

        let ethMeta = CoinGeckoMarketService.token(id: "ethereum")
        var holdings: [HoldingAsset] = [
            HoldingAsset(
                id: "eth-native",
                symbol: ChainConfig.active.symbol,
                name: "\(ChainConfig.active.name) 原生幣",
                balance: formatAmount(eth),
                valueUSD: ethUSD,
                change24hPercent: ethMeta?.change24hPercent ?? 0,
                imageURL: ethMeta?.imageURL
                    ?? TokenLogoCatalog.url(for: "eth")?.absoluteString
            ),
        ]

        if PufferDemoConfig.hasOnChainVault {
            holdings.append(
                HoldingAsset(
                    id: "puffer-pufeth",
                    symbol: PufferDemoConfig.pufETHSymbol,
                    name: "Puffer 質押 · Sepolia",
                    balance: formatAmount(pufETH, maxFraction: 6),
                    valueUSD: pufETHUSD,
                    change24hPercent: 0,
                    imageURL: TokenLogoCatalog.url(for: "eth")?.absoluteString
                )
            )
        }

        if SepoliaSwapDemoConfig.hasOnChainSwap {
            holdings.append(
                HoldingAsset(
                    id: SepoliaSwapDemoConfig.vUSDCMarketId,
                    symbol: SepoliaSwapDemoConfig.vUSDCSymbol,
                    name: "vUSDC 演示代幣 · Sepolia",
                    balance: formatAmount(vUSDC, maxFraction: 6),
                    valueUSD: vUSDCUSD,
                    change24hPercent: 0,
                    imageURL: CoinGeckoMarketService.token(id: "usd-coin")?.imageURL
                        ?? TokenLogoCatalog.url(for: "usdc")?.absoluteString
                )
            )
        }

        let portfolio = PortfolioSummary(
            totalBalanceUSD: totalUSD,
            change24hPercent: 0,
            change24hUSD: 0,
            lastUpdated: Date(),
            currencyCode: "USD"
        )
        return WalletOnChainSnapshot(portfolio: portfolio, holdings: holdings)
    }

    private static func cachedNativeUsdPrice() async -> Decimal {
        if let cached = cachedUsdPerEth,
           let at = cachedUsdPerEthAt,
           Date().timeIntervalSince(at) < usdPriceCacheTTL {
            return cached
        }
        let fresh = (try? await ChainRPCClient.fetchNativeUsdPrice()) ?? cachedUsdPerEth ?? 3_000
        cachedUsdPerEth = fresh
        cachedUsdPerEthAt = Date()
        return fresh
    }

    nonisolated static func formatAmount(_ amount: Decimal, maxFraction: Int = 6) -> String {
        let n = NSDecimalNumber(decimal: amount)
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = maxFraction
        f.numberStyle = .decimal
        return f.string(from: n) ?? "\(amount)"
    }
}
