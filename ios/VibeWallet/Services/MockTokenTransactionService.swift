import Foundation

enum MockTokenTransactionService {
    static func recentTransactions(forTokenId tokenId: String, limit: Int = 12) -> [TokenTransaction] {
        let now = Date()
        let base: [TokenTransaction] = [
            TokenTransaction(
                id: "\(tokenId)-1",
                hash: "0x8f3a2b1c9d0e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9",
                kind: .receive,
                amount: "+0.42",
                counterparty: "0x742d…3a91",
                timestamp: now.addingTimeInterval(-3_600),
                status: "成功"
            ),
            TokenTransaction(
                id: "\(tokenId)-2",
                hash: "0x1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b",
                kind: .send,
                amount: "-0.05",
                counterparty: "0x9f12…88c0",
                timestamp: now.addingTimeInterval(-8_200),
                status: "成功"
            ),
            TokenTransaction(
                id: "\(tokenId)-3",
                hash: "0xdeadbeefcafebabe1234567890abcdef1234567890abcdef1234567890ab",
                kind: .swap,
                amount: "0.1 → 180 USDC",
                counterparty: "Uniswap",
                timestamp: now.addingTimeInterval(-26_000),
                status: "成功"
            ),
            TokenTransaction(
                id: "\(tokenId)-4",
                hash: "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef12345678",
                kind: .contract,
                amount: "授權",
                counterparty: "0xPermit2…",
                timestamp: now.addingTimeInterval(-86_400),
                status: "成功"
            ),
            TokenTransaction(
                id: "\(tokenId)-5",
                hash: "0x1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff",
                kind: .receive,
                amount: "+1.00",
                counterparty: "Sepolia Faucet",
                timestamp: now.addingTimeInterval(-172_800),
                status: "成功"
            ),
        ]
        return Array(base.prefix(limit))
    }
}
