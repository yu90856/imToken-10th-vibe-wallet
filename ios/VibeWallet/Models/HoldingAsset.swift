import Foundation

struct HoldingAsset: Identifiable, Equatable {
    let id: String
    let symbol: String
    let name: String
    let balance: String
    let valueUSD: Decimal
    let change24hPercent: Double
    let imageURL: String?

    var formattedValue: String {
        HoldingAsset.currencyFormatter.string(from: valueUSD as NSDecimalNumber) ?? "$0"
    }

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f
    }()
}
