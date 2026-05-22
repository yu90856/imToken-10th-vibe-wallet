import SwiftUI

struct PortfolioDetailView: View {
    let portfolio: PortfolioSummary
    let holdings: [HoldingAsset]

    @Environment(\.colorScheme) private var colorScheme
    @Environment(WalletSession.self) private var walletSession

    @State private var showSend = false
    @State private var showReceive = false
    @State private var sendPreselectId: String?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: VibeSpacing.xSmall) {
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

                    if walletSession.hasWallet {
                        HStack(spacing: VibeSpacing.xSmall) {
                            transferButton(title: "發送", icon: "arrow.up.right") {
                                sendPreselectId = nil
                                showSend = true
                            }
                            transferButton(title: "接收", icon: "arrow.down.left") {
                                showReceive = true
                            }
                        }
                        .padding(.top, VibeSpacing.xSmall)
                    }
                }
                .padding(.vertical, VibeSpacing.xSmall)
            }

            Section("持倉") {
                if holdings.isEmpty {
                    Text("尚無持倉")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(holdings) { asset in
                        HStack(spacing: 14) {
                            TokenLogoView(tokenId: asset.id, symbol: asset.symbol, imageURL: asset.imageURL, size: 40)

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
                                if WalletTransferService.assetKind(for: asset.id) != nil,
                                   walletSession.hasWallet {
                                    Button("發送") {
                                        sendPreselectId = asset.id
                                        showSend = true
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.primary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section {
                Label(
                    ChainConfig.usesTestnet
                        ? "餘額來自 Sepolia 鏈上查詢；發送請選擇要轉出的代幣。"
                        : "資料僅供本機示範，非鏈上即時報價",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("資產明細")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
        .sheet(isPresented: $showSend) {
            WalletTransferSheet(
                mode: .send,
                holdings: holdings,
                preselectedHoldingId: sendPreselectId
            )
        }
        .sheet(isPresented: $showReceive) {
            WalletTransferSheet(mode: .receive, holdings: holdings)
        }
    }

    private func transferButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                Text(title)
                    .notebookHeadline(15)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(AppTheme.primary)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(AppTheme.primary.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        PortfolioDetailView(
            portfolio: MockHomeDataService().loadPortfolio(),
            holdings: MockHomeDataService().loadHoldings()
        )
        .environment(WalletSession.shared)
    }
}
