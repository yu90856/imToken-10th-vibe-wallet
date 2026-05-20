import Foundation

struct TokenTransaction: Identifiable, Equatable {
    enum Kind: String {
        case send
        case receive
        case swap
        case contract
    }

    let id: String
    let hash: String
    let kind: Kind
    let amount: String
    let counterparty: String?
    let timestamp: Date
    let status: String

    var kindLabel: String {
        switch kind {
        case .send: return "轉出"
        case .receive: return "轉入"
        case .swap: return "交換"
        case .contract: return "合約"
        }
    }

    var shortHash: String {
        guard hash.count > 12 else { return hash }
        return "\(hash.prefix(8))…\(hash.suffix(4))"
    }
}
