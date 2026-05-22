import SwiftUI

struct TokenLogoView: View {
    @Environment(\.colorScheme) private var colorScheme

    let tokenId: String
    let symbol: String
    /// CoinGecko 圖示（優先於靜態表）
    var imageURL: String? = nil
    var size: CGFloat = 40
    /// 在代幣圖示右下角顯示鏈標記（預設開啟，使用 `ChainConfig.active`）
    var showChainBadge: Bool = true
    var chainTokenId: String? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            logoCircle(tokenId: tokenId, symbol: symbol, dimension: size)

            if showChainBadge {
                let badgeSize = max(14, size * 0.38)
                logoCircle(
                    tokenId: chainTokenId ?? ChainConfig.active.tokenLogoId,
                    symbol: "",
                    dimension: badgeSize
                )
                .overlay(
                    Circle()
                        .strokeBorder(badgeRingColor, lineWidth: 2)
                )
                .offset(x: size * 0.02, y: size * 0.02)
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private func logoCircle(tokenId: String, symbol: String, dimension: CGFloat) -> some View {
        Group {
            let catalogId = TokenLogoCatalog.resolveLogoTokenId(tokenId)
            if let url = TokenLogoCatalog.url(from: imageURL)
                ?? TokenLogoCatalog.url(for: catalogId) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        fallback(symbol: symbol, dimension: dimension)
                    case .empty:
                        ProgressView().controlSize(.small)
                    @unknown default:
                        fallback(symbol: symbol, dimension: dimension)
                    }
                }
            } else {
                fallback(symbol: symbol, dimension: dimension)
            }
        }
        .frame(width: dimension, height: dimension)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
    }

    private var badgeRingColor: Color {
        colorScheme == .dark ? AppTheme.paperDark : AppTheme.paperLight
    }

    private func fallback(symbol: String, dimension: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(AppTheme.primary.opacity(0.15))
            Text(String(symbol.prefix(1)).uppercased())
                .font(.system(size: dimension * 0.38, weight: .bold))
                .foregroundStyle(AppTheme.primary)
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        TokenLogoView(tokenId: "eth", symbol: "ETH", size: 48)
        TokenLogoView(tokenId: "usdc", symbol: "USDC", size: 48)
        TokenLogoView(tokenId: "eth", symbol: "ETH", size: 48, showChainBadge: false)
    }
    .padding()
    .background(Color.black)
}
