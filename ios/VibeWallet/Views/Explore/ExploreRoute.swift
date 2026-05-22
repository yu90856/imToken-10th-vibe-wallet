import Foundation

enum ExploreRoute: Hashable {
    case pufferStaking
    case bitrefillShop(initialQuery: String, previewProducts: [BitrefillProductMatch])
    case bitrefillProduct(productId: String)
    case bitrefillCheckout(invoice: BitrefillInvoiceSummary)
}
