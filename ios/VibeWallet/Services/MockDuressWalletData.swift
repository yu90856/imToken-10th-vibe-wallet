import Foundation

enum MockDuressWalletData {
    static let fakeAddress = "0xDeC0y7a1b2c3d4e5f6789012345678901234567890"
    static let fakeShortAddress = "0xDeC0y…7890"

    static let zeroPortfolio = PortfolioSummary(
        totalBalanceUSD: 0,
        change24hPercent: 0,
        change24hUSD: 0,
        lastUpdated: Date(),
        currencyCode: "USD"
    )

    static let zeroHoldings: [HoldingAsset] = [
        HoldingAsset(
            id: "decoy-eth",
            symbol: "ETH",
            name: "Ethereum",
            balance: "0",
            valueUSD: 0,
            change24hPercent: 0,
            imageURL: TokenLogoCatalog.url(for: "eth")?.absoluteString
        ),
    ]

    static func fakeTransactions(forTokenId tokenId: String) -> [TokenTransaction] {
        [
            TokenTransaction(
                id: "decoy-tx-1",
                hash: "0x0000000000000000000000000000000000000000000000000000000000000001",
                kind: .send,
                amount: "-0.12 ETH",
                counterparty: "0x9a11…f2e0",
                timestamp: Date().addingTimeInterval(-7_200),
                status: "成功"
            ),
            TokenTransaction(
                id: "decoy-tx-2",
                hash: "0x0000000000000000000000000000000000000000000000000000000000000002",
                kind: .receive,
                amount: "+0.05 ETH",
                counterparty: "0x4b22…88aa",
                timestamp: Date().addingTimeInterval(-86_400),
                status: "成功"
            ),
        ]
    }
}
