import Foundation

enum HomeRoute: Hashable {
    case portfolio
    case pufferStaking
    case bitrefillShop(initialQuery: String, previewProducts: [BitrefillProductMatch])
    case bitrefillProduct(productId: String)
    case bitrefillCheckout(invoice: BitrefillInvoiceSummary)
    case sovereignty
    case settings
}
