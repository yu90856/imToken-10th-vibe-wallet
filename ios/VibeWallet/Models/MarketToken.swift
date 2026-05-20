import Foundation

enum MarketTokenCategory: String, CaseIterable {
    case mainstream
    case onChain
}

enum MarketSegment: String, CaseIterable, Identifiable {
    case watchlist = "關注清單"
    case mainstream = "主流代幣"
    case onChain = "鏈上代幣"

    var id: String { rawValue }
}

enum MarketSortOption: String, CaseIterable, Identifiable {
    case name = "名稱"
    case volume = "成交量"
    case change24h = "24小時漲跌幅"

    var id: String { rawValue }
}

struct MarketToken: Identifiable, Equatable, Hashable {
    let id: String
    let symbol: String
    let name: String
    let contractAddress: String
    let priceUSD: Decimal
    let change24hPercent: Double
    let volume24hUSD: Decimal
    let category: MarketTokenCategory
    /// 錢包內可兌換資產
    let walletBalance: Decimal?
    /// CoinGecko 圖示 URL
    let imageURL: String?

    var formattedPrice: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        if priceUSD < 0.01 {
            f.maximumFractionDigits = 8
        } else if priceUSD < 1 {
            f.maximumFractionDigits = 4
        } else {
            f.maximumFractionDigits = 2
        }
        return f.string(from: priceUSD as NSDecimalNumber) ?? "$0"
    }

    var formattedVolume: String {
        MarketToken.volumeFormatter.string(from: volume24hUSD as NSDecimalNumber) ?? "$0"
    }

    var formattedChange: String {
        String(format: "%+.2f%%", change24hPercent)
    }

    var isPositiveChange: Bool { change24hPercent >= 0 }

    var shortContract: String {
        guard contractAddress.count > 12 else { return contractAddress }
        let start = contractAddress.prefix(6)
        let end = contractAddress.suffix(4)
        return "\(start)...\(end)"
    }

    func matchesSearch(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        return name.lowercased().contains(q)
            || symbol.lowercased().contains(q)
            || contractAddress.lowercased().contains(q)
    }

    private static let volumeFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f
    }()
}
