import SwiftUI

struct AssetBalanceCard: View {
    let portfolio: PortfolioSummary
    @Environment(\.colorScheme) private var colorScheme

    private var isPositive: Bool { portfolio.change24hPercent >= 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
                HStack {
                    HStack(spacing: 6) {
                        SketchIcon(kind: .chart, size: 18, color: AppTheme.ink.opacity(0.55))
                        Text("總資產")
                            .notebookHeadline(17)
                    }
                    .foregroundStyle(AppTheme.ink.opacity(0.7))
                    Spacer()
                    BNBChainBadge(compact: true)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.quaternary))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(portfolio.formattedTotal)
                        .font(NotebookFont.largeAmount(40))
                        .foregroundStyle(AppTheme.ink)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    HStack(spacing: 10) {
                        ChangeBadge(
                            percent: portfolio.change24hPercent,
                            isPositive: isPositive
                        )
                        Text(portfolio.formattedChangeUSD)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(isPositive ? AppTheme.positive : AppTheme.negative)
                        Text("24h")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Divider().opacity(colorScheme == .dark ? 0.2 : 0.5)

                HStack(spacing: 16) {
                    MiniStat(tokenId: "eth", symbol: "ETH", value: "—")
                    MiniStat(tokenId: "usdc", symbol: "USDC", value: "—")
                }
        }
        .padding(20)
        .glassCard(cornerRadius: 12, variant: .yellow, tilt: 0.5)
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    colorScheme == .dark
                        ? LinearGradient(
                            colors: [
                                Color(red: 15 / 255, green: 28 / 255, blue: 67 / 255),
                                Color(red: 8 / 255, green: 18 / 255, blue: 45 / 255),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [.white, Color(red: 240 / 255, green: 247 / 255, blue: 1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.primary.opacity(0.12),
                            AppTheme.secondary.opacity(0.06),
                            .clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        AppTheme.primary.opacity(colorScheme == .dark ? 0.5 : 0.35),
                        AppTheme.secondary.opacity(0.2),
                        .white.opacity(colorScheme == .dark ? 0.08 : 0.6),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

private struct ChangeBadge: View {
    let percent: Double
    let isPositive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(isPositive ? "↑" : "↓")
                .notebookCaption(11)
            Text(String(format: "%+.2f%%", percent))
                .notebookCaption(12)
        }
        .foregroundStyle(isPositive ? AppTheme.positive : AppTheme.negative)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill((isPositive ? AppTheme.positive : AppTheme.negative).opacity(0.15))
        )
    }
}

private struct MiniStat: View {
    let tokenId: String
    let symbol: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TokenLogoView(tokenId: tokenId, symbol: symbol, size: 28)
            Text(value)
                .notebookBody(14)
            Text(symbol)
                .notebookCaption(11)
                .foregroundStyle(AppTheme.ink.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    AssetBalanceCard(
        portfolio: MockHomeDataService().loadPortfolio()
    )
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
