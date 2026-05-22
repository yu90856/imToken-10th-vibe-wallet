import SwiftUI

struct HomeShoppingWishlistRow: Identifiable {
    let id: String
    let reminderTitle: String
    let statusLine: String
    let topProductName: String?
    let searchQuery: String
    /// 首頁預覽搜尋結果（帶入 Bitrefill 商店頁顯示圖片）
    let previewProducts: [BitrefillProductMatch]
}

struct HomeShoppingStickyCard: View {
    let rows: [HomeShoppingWishlistRow]
    let bannerMessage: String?
    let isLoading: Bool
    var onRefresh: () -> Void
    var onOpenShop: (HomeShoppingWishlistRow) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("購物清單")
                        .notebookHeadline(17)
                        .foregroundStyle(AppTheme.ink)
                    Text("來自提醒事項「\(ShoppingRemindersService.listTitle)」")
                        .notebookCaption(11)
                        .foregroundStyle(AppTheme.ink.opacity(0.5))
                }
                Spacer()
                Button(action: onRefresh) {
                    SketchIcon(kind: .refresh, size: 18, color: AppTheme.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("重新整理購物待辦")
            }

            if let bannerMessage {
                Text(bannerMessage)
                    .notebookCaption(12)
                    .foregroundStyle(AppTheme.ink.opacity(0.65))
            }

            if isLoading && rows.isEmpty {
                Text("正在讀取待辦並搜尋 Bitrefill…")
                    .notebookBody(14)
                    .foregroundStyle(AppTheme.ink.opacity(0.5))
            } else if rows.isEmpty {
                Text("在「提醒事項」的「\(ShoppingRemindersService.listTitle)」清單新增項目，回到首頁即可顯示。")
                    .notebookBody(14)
                    .foregroundStyle(AppTheme.ink.opacity(0.55))
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Divider().opacity(0.35)
                    }
                    Button {
                        onOpenShop(row)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            if let top = row.previewProducts.first {
                                BitrefillProductImageView(
                                    productId: top.id,
                                    imageURL: top.imageURL,
                                    size: 48,
                                    cornerRadius: 10
                                )
                            } else {
                                BitrefillProductImageView(
                                    productId: row.searchQuery,
                                    imageURL: nil,
                                    size: 48,
                                    cornerRadius: 10
                                )
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.reminderTitle)
                                    .notebookHeadline(15)
                                    .foregroundStyle(AppTheme.ink)
                                    .multilineTextAlignment(.leading)
                                Text(row.statusLine)
                                    .notebookCaption(11)
                                    .foregroundStyle(
                                        row.topProductName != nil ? AppTheme.positive : AppTheme.ink.opacity(0.5)
                                    )
                                if let product = row.topProductName {
                                    Text("↗ \(product)")
                                        .notebookCaption(11)
                                        .foregroundStyle(AppTheme.primary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16, variant: .mint, tilt: 0.6)
    }
}
