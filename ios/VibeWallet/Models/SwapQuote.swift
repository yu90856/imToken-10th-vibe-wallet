import Foundation

struct SwapQuote: Equatable {
    let routeDescription: String
    let exchangeRate: String
    let minimumReceived: String
    let serviceFee: String
    let slippagePercent: Double
    let mevProtectionEnabled: Bool

    static let empty = SwapQuote(
        routeDescription: "—",
        exchangeRate: "—",
        minimumReceived: "—",
        serviceFee: "—",
        slippagePercent: 0.5,
        mevProtectionEnabled: true
    )
}
