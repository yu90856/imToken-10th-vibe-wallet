import Foundation

struct PortfolioSummary: Equatable {
    let totalBalanceUSD: Decimal
    let change24hPercent: Double
    let change24hUSD: Decimal
    let lastUpdated: Date
    let currencyCode: String

    var formattedTotal: String {
        PortfolioSummary.currencyFormatter.string(from: totalBalanceUSD as NSDecimalNumber)
            ?? "$0.00"
    }

    var formattedChangeUSD: String {
        let prefix = change24hUSD >= 0 ? "+" : "-"
        let value =
            PortfolioSummary.currencyFormatter.string(
                from: abs(change24hUSD) as NSDecimalNumber
            ) ?? "$0.00"
        return "\(prefix)\(value)"
    }

    var formattedChangePercent: String {
        String(format: "%+.2f%%", change24hPercent)
    }

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()
}
