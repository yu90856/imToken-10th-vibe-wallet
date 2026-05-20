import Foundation

struct WalletAccount: Codable, Equatable {
    let address: String
    let chainId: Int
    let createdAt: Date
    let label: String

    var shortAddress: String {
        guard address.count > 12 else { return address }
        let start = address.prefix(6)
        let end = address.suffix(4)
        return "\(start)...\(end)"
    }
}
