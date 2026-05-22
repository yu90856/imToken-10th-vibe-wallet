import Foundation

/// Sepolia 測試網可交換代幣（含鏈上餘額）
enum SepoliaSwapTokenCatalog {
    static let usdtMarketId = "tether"

    /// 錢包持倉 id → 行情／交換 MarketToken.id
    static func marketTokenId(forHoldingId holdingId: String) -> String? {
        switch holdingId {
        case "eth-native": return "ethereum"
        case "puffer-pufeth": return "puffer-pufeth"
        case SepoliaSwapDemoConfig.vUSDCMarketId: return SepoliaSwapDemoConfig.vUSDCMarketId
        default: return nil
        }
    }

    /// 將 `WalletOnChainHoldingsService` 持倉餘額寫入交換代幣列表
    @MainActor
    static func applyHeldBalances(from snapshot: WalletOnChainSnapshot, into tokens: inout [MarketToken]) {
        var balancesByMarketId: [String: Decimal] = [:]
        for holding in snapshot.holdings {
            guard let marketId = marketTokenId(forHoldingId: holding.id),
                  let amount = parseBalanceAmount(holding.balance) else { continue }
            balancesByMarketId[marketId] = amount
        }
        for index in tokens.indices {
            let id = tokens[index].id
            if let balance = balancesByMarketId[id] {
                tokens[index] = tokens[index].with(walletBalance: balance)
            }
        }
    }

    /// 交換代幣選擇器：持倉優先，其餘依代號排序
    static func sortForTokenPicker(_ tokens: [MarketToken]) -> [MarketToken] {
        tokens.sorted { lhs, rhs in
            let lhsHeld = hasPositiveBalance(lhs)
            let rhsHeld = hasPositiveBalance(rhs)
            if lhsHeld != rhsHeld { return lhsHeld && !rhsHeld }
            return lhs.symbol.localizedCaseInsensitiveCompare(rhs.symbol) == .orderedAscending
        }
    }

    static func balanceLabel(for token: MarketToken) -> String? {
        guard let balance = token.walletBalance, balance > 0 else { return nil }
        return "餘額 \(formatPickerAmount(balance)) \(token.symbol)"
    }

    private static func hasPositiveBalance(_ token: MarketToken) -> Bool {
        (token.walletBalance ?? 0) > 0
    }

    private static func parseBalanceAmount(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed.replacingOccurrences(of: ",", with: ""))
    }

    private static func formatPickerAmount(_ value: Decimal) -> String {
        WalletOnChainHoldingsService.formatAmount(value, maxFraction: 8)
    }

    static func isUSDTAnchor(_ tokenId: String) -> Bool {
        tokenId == usdtMarketId
    }

    /// 行情／交換預設「支付」端：USDT（CoinGecko 報價，非鏈上餘額）
    @MainActor
    static func usdtAnchorToken() -> MarketToken {
        let ref = CoinGeckoMarketService.token(id: usdtMarketId)
        return MarketToken(
            id: usdtMarketId,
            symbol: "USDT",
            name: ref?.name ?? "Tether USD",
            contractAddress: "",
            priceUSD: ref?.priceUSD ?? 1,
            change24hPercent: ref?.change24hPercent ?? 0,
            volume24hUSD: ref?.volume24hUSD ?? 0,
            category: .mainstream,
            walletBalance: nil,
            imageURL: ref?.imageURL ?? TokenLogoCatalog.url(for: "usdt")?.absoluteString
        )
    }

    @MainActor
    static func ensureUSDT(in tokens: inout [MarketToken]) -> MarketToken {
        if let existing = tokens.first(where: { isUSDTAnchor($0.id) }) {
            return existing
        }
        let usdt = usdtAnchorToken()
        tokens.insert(usdt, at: 0)
        return usdt
    }

    @MainActor
    static func loadSwappableTokens() async -> [MarketToken] {
        guard ChainConfig.usesTestnet,
              let address = WalletSession.shared.account?.address else {
            return []
        }

        _ = await CoinGeckoMarketService.refreshIfNeeded()
        let ethPrice = CoinGeckoMarketService.token(id: "ethereum")
        let usdcPrice = CoinGeckoMarketService.token(id: "usd-coin")

        let ethBal = (try? await ChainRPCClient.fetchNativeBalance(address: address)) ?? 0
        let pufBal = await PufferStakingService.pufETHBalance(address: address)
        let vusdcBal = await SepoliaSwapService.vUSDCBalance(address: address)

        var tokens: [MarketToken] = []

        tokens.append(
            MarketToken(
                id: "ethereum",
                symbol: "ETH",
                name: "Ethereum Sepolia",
                contractAddress: "",
                priceUSD: ethPrice?.priceUSD ?? 3_000,
                change24hPercent: ethPrice?.change24hPercent ?? 0,
                volume24hUSD: ethPrice?.volume24hUSD ?? 0,
                category: .mainstream,
                walletBalance: ethBal,
                imageURL: ethPrice?.imageURL ?? TokenLogoCatalog.url(for: "eth")?.absoluteString
            )
        )

        if PufferDemoConfig.hasOnChainVault {
            let rate = await PufferStakingService.loadExchangeRate()
            tokens.append(
                MarketToken(
                    id: "puffer-pufeth",
                    symbol: PufferDemoConfig.pufETHSymbol,
                    name: "Puffer 質押 · Sepolia",
                    contractAddress: PufferDemoConfig.sepoliaVaultAddress,
                    priceUSD: (ethPrice?.priceUSD ?? 3_000) * rate.ethPerPufEth,
                    change24hPercent: 0,
                    volume24hUSD: 0,
                    category: .onChain,
                    walletBalance: pufBal,
                    imageURL: ethPrice?.imageURL
                )
            )
        }

        if SepoliaSwapDemoConfig.hasOnChainSwap {
            tokens.append(
                MarketToken(
                    id: SepoliaSwapDemoConfig.vUSDCMarketId,
                    symbol: SepoliaSwapDemoConfig.vUSDCSymbol,
                    name: "Vibe 演示 USDC · Sepolia",
                    contractAddress: SepoliaSwapDemoConfig.contractAddress,
                    priceUSD: usdcPrice?.priceUSD ?? 1,
                    change24hPercent: 0,
                    volume24hUSD: 0,
                    category: .mainstream,
                    walletBalance: vusdcBal,
                    imageURL: usdcPrice?.imageURL ?? TokenLogoCatalog.url(for: "usdc")?.absoluteString
                )
            )
        }

        _ = ensureUSDT(in: &tokens)
        return tokens
    }

    /// 行情全集 + Sepolia 鏈上餘額（測試網交換代幣選擇器）
    @MainActor
    static func mergeCatalogWithOnChain(catalog: [MarketToken], onChain: [MarketToken]) -> [MarketToken] {
        var byId = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        for token in onChain {
            if let existing = byId[token.id] {
                byId[token.id] = existing.with(walletBalance: token.walletBalance)
            } else {
                byId[token.id] = token
            }
        }
        var merged = Array(byId.values)
        _ = ensureUSDT(in: &merged)
        if let snapshot = WalletBalanceStore.shared.snapshot {
            applyHeldBalances(from: snapshot, into: &merged)
        }
        return sortForTokenPicker(merged)
    }

    /// 以行情點選的代幣為準（保留價格／名稱），並寫入列表
    @MainActor
    static func mergeMarketToken(_ market: MarketToken, into tokens: [MarketToken]) -> [MarketToken] {
        var list = tokens
        if let idx = list.firstIndex(where: { $0.id == market.id }) {
            let existing = list[idx]
            list[idx] = MarketToken(
                id: market.id,
                symbol: market.symbol,
                name: market.name,
                contractAddress: market.contractAddress.isEmpty ? existing.contractAddress : market.contractAddress,
                priceUSD: market.priceUSD,
                change24hPercent: market.change24hPercent,
                volume24hUSD: market.volume24hUSD,
                category: market.category,
                walletBalance: existing.walletBalance,
                imageURL: market.imageURL ?? existing.imageURL
            )
        } else {
            list.append(market)
        }
        _ = ensureUSDT(in: &list)
        return list
    }

    static func isSepoliaSettlable(_ tokenId: String) -> Bool {
        let id = SepoliaSwapService.normalizeTokenId(tokenId)
        return id == "ethereum"
            || id == SepoliaSwapDemoConfig.vUSDCMarketId
            || id == "puffer-pufeth"
    }

    static func usesCrossChainBridge(from: MarketToken, to: MarketToken) -> Bool {
        if isUSDTAnchor(from.id), !isSepoliaSettlable(to.id) { return true }
        if isUSDTAnchor(to.id), !isSepoliaSettlable(from.id) { return true }
        return false
    }

    static func routeDescription(
        from: MarketToken,
        to: MarketToken,
        onChain: Bool,
        mevProtectionEnabled: Bool
    ) -> String {
        if onChain {
            if mevProtectionEnabled {
                return "\(from.symbol) → \(to.symbol) · Sepolia 演示合約"
            }
            return "\(from.symbol) → \(to.symbol) · Sepolia 鏈上"
        }
        if usesCrossChainBridge(from: from, to: to) {
            return "USDT → 跨鏈橋 → \(to.symbol) · CoinGecko 參考（Sepolia 測試網不結算）"
        }
        if isUSDTAnchor(from.id) {
            return "USDT → \(to.symbol) · CoinGecko 參考報價（Sepolia 測試網）"
        }
        return "\(from.symbol) → \(to.symbol) · CoinGecko 參考報價"
    }

    static func buildQuote(
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

        let onChain = isOnChainPair(fromId: from.id, toId: to.id)
        let route = routeDescription(
            from: from,
            to: to,
            onChain: onChain,
            mevProtectionEnabled: mevProtectionEnabled
        )
        let bridgeFee = usesCrossChainBridge(from: from, to: to) ? "橋接費（參考）~0.1%" : "—"

        return SwapQuote(
            routeDescription: route,
            exchangeRate: rateText,
            minimumReceived: minText,
            serviceFee: onChain ? "演示 0.3%" : bridgeFee,
            slippagePercent: slippagePercent,
            mevProtectionEnabled: mevProtectionEnabled
        )
    }

    static func isOnChainPair(fromId: String, toId: String) -> Bool {
        let from = SepoliaSwapService.normalizeTokenId(fromId)
        let to = SepoliaSwapService.normalizeTokenId(toId)
        switch (from, to) {
        case ("ethereum", SepoliaSwapDemoConfig.vUSDCMarketId),
             (SepoliaSwapDemoConfig.vUSDCMarketId, "ethereum"),
             ("ethereum", "puffer-pufeth"):
            return true
        default:
            return false
        }
    }

    /// 行情代幣 → 交換 Tab「接收」端；支付端固定 USDT
    static func resolvePreselectedToken(_ token: MarketToken?) -> MarketToken? {
        guard let token, !isUSDTAnchor(token.id) else { return nil }
        return token
    }
}
