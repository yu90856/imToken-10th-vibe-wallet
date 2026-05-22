import Foundation
import Observation

enum SwapAmountField {
    case from
    case to
}

@MainActor
@Observable
final class SwapViewModel {
    private(set) var walletTokens: [MarketToken] = []
    var fromToken: MarketToken?
    var toToken: MarketToken?
    var amountFromText = ""
    var amountToText = ""
    var slippagePercent: Double = 0.5
    var mevProtectionEnabled = true

    private(set) var isRefreshing = false
    private(set) var isSwapping = false
    private(set) var lastSwapMessage: String?
    private(set) var lastTxHash: String?

    private var lastEdited: SwapAmountField = .from
    private var suppressRecalculation = false

    private let feeMultiplier = Decimal(string: "0.997")!
    /// 從行情帶入的接收代幣（refresh 時保留，避免被重設成 ETH）
    private let marketPreselectedTo: MarketToken?

    init(preselectedTo: MarketToken?) {
        marketPreselectedTo = preselectedTo
        applyTokenSelection(
            preselectedTo: SepoliaSwapTokenCatalog.resolvePreselectedToken(preselectedTo)
        )
    }

    @MainActor
    func refreshTokens(preselectedTo override: MarketToken? = nil) async {
        isRefreshing = true
        defer { isRefreshing = false }

        let resolvedTarget = SepoliaSwapTokenCatalog.resolvePreselectedToken(
            override ?? marketPreselectedTo
        )

        await WalletBalanceStore.shared.refresh()

        if ChainConfig.usesTestnet {
            _ = await CoinGeckoMarketService.refreshIfNeeded()
            let catalog = CoinGeckoMarketService.cachedTokens()
            let onChain = await SepoliaSwapTokenCatalog.loadSwappableTokens()
            walletTokens = SepoliaSwapTokenCatalog.mergeCatalogWithOnChain(
                catalog: catalog,
                onChain: onChain
            )
        } else {
            _ = await CoinGeckoMarketService.refreshIfNeeded()
            var all = await CoinGeckoMarketService.mergeWalletBalances(
                into: CoinGeckoMarketService.cachedTokens()
            )
            _ = SepoliaSwapTokenCatalog.ensureUSDT(in: &all)
            walletTokens = all.filter { ($0.walletBalance ?? 0) > 0 }
            if walletTokens.isEmpty {
                walletTokens = all
            }
            if !walletTokens.contains(where: { SepoliaSwapTokenCatalog.isUSDTAnchor($0.id) }) {
                _ = SepoliaSwapTokenCatalog.ensureUSDT(in: &walletTokens)
            }
            walletTokens = SepoliaSwapTokenCatalog.sortForTokenPicker(walletTokens)
        }
        applyTokenSelection(preselectedTo: resolvedTarget)
    }

    private func applyTokenSelection(preselectedTo: MarketToken?) {
        var all = walletTokens
        let usdt = SepoliaSwapTokenCatalog.ensureUSDT(in: &all)
        walletTokens = SepoliaSwapTokenCatalog.sortForTokenPicker(all)
        fromToken = usdt

        guard let preselectedTo, preselectedTo.id != usdt.id else {
            toToken = all.first { $0.id == "ethereum" }
                ?? all.first { !SepoliaSwapTokenCatalog.isUSDTAnchor($0.id) && $0.id != usdt.id }
            return
        }

        let merged = SepoliaSwapTokenCatalog.mergeMarketToken(preselectedTo, into: all)
        walletTokens = SepoliaSwapTokenCatalog.sortForTokenPicker(merged)
        toToken = walletTokens.first { $0.id == preselectedTo.id } ?? preselectedTo
    }

    /// 行情進入時為參考報價（USDT → 代幣），非 Sepolia 鏈上結算
    var isReferenceQuoteOnly: Bool {
        guard let from = fromToken, toToken != nil else { return false }
        return SepoliaSwapTokenCatalog.isUSDTAnchor(from.id) && !canExecuteOnChain
    }

    var quote: SwapQuote {
        guard let from = fromToken,
              let to = toToken,
              let amount = parsedFromAmount,
              amount > 0 else {
            return SwapQuote.empty
        }
        if ChainConfig.usesTestnet,
           let built = SepoliaSwapTokenCatalog.buildQuote(
               from: from,
               to: to,
               amountIn: amount,
               slippagePercent: slippagePercent,
               mevProtectionEnabled: mevProtectionEnabled
           ) {
            return built
        }
        return SwapQuote.empty
    }

    var canExecuteOnChain: Bool {
        guard let from = fromToken, let to = toToken else { return false }
        return SepoliaSwapTokenCatalog.isOnChainPair(fromId: from.id, toId: to.id)
    }

    var hasValidQuote: Bool {
        guard fromToken != nil, toToken != nil else { return false }
        let fromAmt = parsedFromAmount ?? 0
        let toAmt = parsedToAmount ?? 0
        return fromAmt > 0 || toAmt > 0
    }

    var fromBalanceLabel: String {
        guard let from = fromToken else { return "餘額 —" }
        if SepoliaSwapTokenCatalog.isUSDTAnchor(from.id) {
            return "參考報價 · Sepolia 測試網"
        }
        guard let bal = from.walletBalance else { return "餘額 —" }
        return "餘額 \(formatAmount(bal)) \(from.symbol)"
    }

    var swapDisabledReason: String? {
        guard hasValidQuote else { return "請輸入交換數量" }
        if isReferenceQuoteOnly { return nil }
        guard canExecuteOnChain else {
            return "請改選 ETH ↔ vUSDC 或 ETH → pufETH 以執行 Sepolia 鏈上交換"
        }
        guard let amount = parsedFromAmount, amount > 0 else { return "請輸入支付數量" }
        guard let bal = fromToken?.walletBalance, bal >= amount else { return "支付代幣餘額不足" }
        if fromToken?.id == "ethereum" {
            let reserve = SepoliaSwapDemoConfig.gasReserveEther
            if bal < amount + reserve { return "需預留約 \(formatAmount(reserve)) ETH 作 Gas" }
        }
        return nil
    }

    func setMaxFromAmount() {
        guard var bal = fromToken?.walletBalance else { return }
        if fromToken?.id == "ethereum" {
            bal = max(0, bal - SepoliaSwapDemoConfig.gasReserveEther)
        }
        updateFromAmount(formatAmount(bal))
    }

    func updateFromAmount(_ text: String) {
        guard !suppressRecalculation else { return }
        amountFromText = text
        lastEdited = .from
        recalculateAmounts()
    }

    func updateToAmount(_ text: String) {
        guard !suppressRecalculation else { return }
        amountToText = text
        lastEdited = .to
        recalculateAmounts()
    }

    func swapDirection() {
        let previousFrom = fromToken
        let previousTo = toToken
        let previousFromAmount = amountFromText
        let previousToAmount = amountToText

        if let to = previousTo, walletTokens.contains(where: { $0.id == to.id }) {
            fromToken = to
        }
        toToken = previousFrom

        suppressRecalculation = true
        amountFromText = previousToAmount
        amountToText = previousFromAmount
        suppressRecalculation = false
        lastEdited = .from
    }

    func tokensForPicker(excludingTokenId: String?) -> [MarketToken] {
        SepoliaSwapTokenCatalog.sortForTokenPicker(
            walletTokens.filter { $0.id != excludingTokenId }
        )
    }

    func allReceivableTokens() -> [MarketToken] {
        tokensForPicker(excludingTokenId: fromToken?.id)
    }

    var fromTokensForPicker: [MarketToken] {
        tokensForPicker(excludingTokenId: toToken?.id)
    }

    func onTokenChanged() {
        recalculateAmounts()
    }

    @MainActor
    func executeSwap(walletAddress: String, walletPassword: String) async throws {
        guard let from = fromToken, let to = toToken,
              let amount = parsedFromAmount, amount > 0 else {
            throw SepoliaSwapError.invalidAmount
        }
        isSwapping = true
        defer { isSwapping = false }

        let result = try await SepoliaSwapService.executeSwap(
            fromTokenId: from.id,
            toTokenId: to.id,
            amountIn: amount,
            walletAddress: walletAddress,
            walletPassword: walletPassword,
            slippagePercent: slippagePercent
        )
        var message = "鏈上已確認：\(formatAmount(result.amountIn)) \(result.fromSymbol) → \(formatAmount(result.amountOut)) \(result.toSymbol)"
        if result.toSymbol == SepoliaSwapDemoConfig.vUSDCSymbol {
            let bal = await SepoliaSwapService.vUSDCBalance(address: walletAddress)
            message += "\n目前 vUSDC 餘額：\(formatAmount(bal))（演示代幣，請在錢包持倉查看）"
        } else if result.toSymbol == PufferDemoConfig.pufETHSymbol {
            let bal = await PufferStakingService.pufETHBalance(address: walletAddress)
            message += "\n目前 pufETH 餘額：\(formatAmount(bal))"
        }

        lastSwapMessage = message
        lastTxHash = result.transactionHash
        NotificationCenter.default.post(name: .walletBalancesDidChange, object: nil)
        await refreshTokens()
    }

    private var parsedFromAmount: Decimal? {
        parseDecimal(amountFromText)
    }

    private var parsedToAmount: Decimal? {
        parseDecimal(amountToText)
    }

    private func recalculateAmounts() {
        guard let from = fromToken, let to = toToken,
              from.priceUSD > 0, to.priceUSD > 0 else { return }

        suppressRecalculation = true
        defer { suppressRecalculation = false }

        switch lastEdited {
        case .from:
            guard let input = parsedFromAmount, input > 0 else {
                if amountFromText.isEmpty { amountToText = "" }
                return
            }
            let usd = input * from.priceUSD
            let out = (usd / to.priceUSD) * feeMultiplier
            amountToText = formatAmount(out)

        case .to:
            guard let input = parsedToAmount, input > 0 else {
                if amountToText.isEmpty { amountFromText = "" }
                return
            }
            let usd = input * to.priceUSD
            let inp = (usd / from.priceUSD) / feeMultiplier
            amountFromText = formatAmount(inp)
        }
    }

    private func parseDecimal(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed.replacingOccurrences(of: ",", with: ""))
    }

    private func formatAmount(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 8
        f.minimumFractionDigits = 0
        return f.string(from: value as NSDecimalNumber) ?? "0"
    }
}
