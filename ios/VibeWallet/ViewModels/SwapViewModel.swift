import Foundation
import Observation

enum SwapAmountField {
    case from
    case to
}

@Observable
final class SwapViewModel {
    private(set) var walletTokens: [MarketToken] = []
    var fromToken: MarketToken?
    var toToken: MarketToken?
    var amountFromText = ""
    var amountToText = ""
    var slippagePercent: Double = 0.5
    var mevProtectionEnabled = true

    private var lastEdited: SwapAmountField = .from
    private var suppressRecalculation = false

    private let marketService = MockMarketDataService()
    private let feeMultiplier = Decimal(string: "0.997")!

    init(preselectedTo: MarketToken?) {
        applyTokenSelection(preselectedTo: preselectedTo)
    }

    @MainActor
    func refreshTokens(preselectedTo: MarketToken? = nil) async {
        _ = await CoinGeckoMarketService.refreshIfNeeded()
        applyTokenSelection(preselectedTo: preselectedTo)
    }

    private func applyTokenSelection(preselectedTo: MarketToken?) {
        let all = CoinGeckoMarketService.cachedTokens()
        walletTokens = all.filter { ($0.walletBalance ?? 0) > 0 }
        if walletTokens.isEmpty {
            walletTokens = all.filter { ["ethereum", "usd-coin"].contains($0.id) }
        }
        fromToken = walletTokens.first { $0.id == "usd-coin" || $0.symbol == "USDC" } ?? walletTokens.first
        toToken = preselectedTo
            ?? all.first { $0.id == "ethereum" || $0.symbol == "ETH" }
            ?? walletTokens.first { $0.id == "ethereum" }
            ?? all.first
    }

    var quote: SwapQuote {
        guard let from = fromToken,
              let to = toToken,
              let amount = parsedFromAmount,
              amount > 0,
              let built = marketService.buildQuote(
                from: from,
                to: to,
                amountIn: amount,
                slippagePercent: slippagePercent,
                mevProtectionEnabled: mevProtectionEnabled
              )
        else {
            return SwapQuote.empty
        }
        return built
    }

    var hasValidQuote: Bool {
        guard fromToken != nil, toToken != nil else { return false }
        let fromAmt = parsedFromAmount ?? 0
        let toAmt = parsedToAmount ?? 0
        return fromAmt > 0 || toAmt > 0
    }

    var fromBalanceLabel: String {
        guard let from = fromToken, let bal = from.walletBalance else { return "餘額 —" }
        return "餘額 \(formatAmount(bal)) \(from.symbol)"
    }

    func setMaxFromAmount() {
        guard let bal = fromToken?.walletBalance else { return }
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

    func allReceivableTokens() -> [MarketToken] {
        CoinGeckoMarketService.cachedTokens()
    }

    func onTokenChanged() {
        recalculateAmounts()
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
