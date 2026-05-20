import SwiftUI

/// 目前鏈標籤（Sepolia / Ethereum）
struct BNBChainBadge: View {
    var compact = false

    private var chain: EVMChain { ChainConfig.active }

    var body: some View {
        HStack(spacing: 4) {
            TokenLogoView(
                tokenId: chain.tokenLogoId,
                symbol: chain.symbol,
                size: compact ? 14 : 18,
                showChainBadge: false
            )
            Text(compact ? chain.shortName : chain.name)
                .font(NotebookFont.label(compact ? 10 : 12))
                .lineLimit(1)
        }
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 3 : 4)
        .background(Capsule().fill(badgeFill))
        .foregroundStyle(badgeForeground)
    }

    private var badgeFill: Color {
        chain.isTestnet ? AppTheme.warning.opacity(0.18) : AppTheme.primary.opacity(0.12)
    }

    private var badgeForeground: Color {
        chain.isTestnet ? AppTheme.warning : AppTheme.primary
    }
}
