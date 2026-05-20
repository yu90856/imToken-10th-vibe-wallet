import SwiftUI

struct MarketTokenRowContent: View {
    let token: MarketToken

    var body: some View {
        HStack(spacing: 12) {
            TokenLogoView(tokenId: token.id, symbol: token.symbol, imageURL: token.imageURL, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(token.symbol)
                        .font(.subheadline.weight(.bold))
                    Text(token.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text("量 \(token.formattedVolume)")
                    .font(.caption2)
                    .foregroundStyle(Color.secondary.opacity(0.8))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(token.formattedPrice)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(token.formattedChange)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        token.isPositiveChange ? AppTheme.positive : AppTheme.negative
                    )
            }
        }
        .padding(.vertical, 6)
    }
}
