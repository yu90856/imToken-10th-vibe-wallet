import SwiftUI

struct PortfolioDetailView: View {
    let portfolio: PortfolioSummary
    let holdings: [HoldingAsset]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("總資產")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(portfolio.formattedTotal)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    HStack {
                        Text(String(format: "%+.2f%%", portfolio.change24hPercent))
                            .foregroundStyle(
                                portfolio.change24hPercent >= 0
                                    ? AppTheme.positive
                                    : AppTheme.negative
                            )
                        Text("24 小時")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline.weight(.medium))
                }
                .padding(.vertical, 8)
            }

            Section("持倉 · Mock") {
                ForEach(holdings) { asset in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.primary.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Text(String(asset.symbol.prefix(1)))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppTheme.primary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(asset.name)
                                .font(.subheadline.weight(.semibold))
                            Text("\(asset.balance) \(asset.symbol)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(asset.formattedValue)
                                .font(.subheadline.weight(.semibold))
                            Text(String(format: "%+.1f%%", asset.change24hPercent))
                                .font(.caption)
                                .foregroundStyle(
                                    asset.change24hPercent >= 0
                                        ? AppTheme.positive
                                        : AppTheme.negative
                                )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Label("資料僅供本機示範，非鏈上即時報價", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("資產明細")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
    }
}

#Preview {
    NavigationStack {
        PortfolioDetailView(
            portfolio: MockHomeDataService().loadPortfolio(),
            holdings: MockHomeDataService().loadHoldings()
        )
    }
}
