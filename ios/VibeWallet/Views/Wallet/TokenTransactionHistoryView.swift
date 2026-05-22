import SwiftUI

struct TokenTransactionHistoryView: View {
    let holding: HoldingAsset
    @Environment(WalletSession.self) private var walletSession
    @Environment(\.colorScheme) private var colorScheme
    @State private var transactions: [TokenTransaction] = []
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                Text("鏈上交易紀錄")
                    .notebookHeadline(17)
                    .foregroundStyle(AppTheme.ink)
                    .padding(.horizontal, 4)

                if isLoading && transactions.isEmpty {
                    ProgressView("讀取 Sepolia 紀錄…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if let loadError, transactions.isEmpty {
                    Text(loadError)
                        .notebookBody(14)
                        .foregroundStyle(AppTheme.negative)
                        .padding(.vertical, 16)
                } else if transactions.isEmpty {
                    Text("尚無鏈上交易紀錄")
                        .notebookBody(14)
                        .foregroundStyle(AppTheme.ink.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    ForEach(transactions) { tx in
                        transactionRow(tx)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .walletDeckScrollInset()
        .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
        .navigationTitle(holding.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: walletSession.account?.address) {
            await loadTransactions()
        }
        .refreshable {
            await loadTransactions()
        }
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            TokenLogoView(tokenId: holding.id, symbol: holding.symbol, imageURL: holding.imageURL, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(holding.name)
                    .notebookHeadline(18)
                    .foregroundStyle(AppTheme.ink)
                Text("\(holding.balance) \(holding.symbol)")
                    .notebookBody(14)
                    .foregroundStyle(AppTheme.ink.opacity(0.65))
                Text(holding.formattedValue)
                    .notebookCaption(12)
                    .foregroundStyle(AppTheme.primary)
            }
            Spacer()
        }
        .padding(16)
        .glassCard(cornerRadius: 16, variant: .yellow, tilt: 0.6)
    }

    private func transactionRow(_ tx: TokenTransaction) -> some View {
        Button {
            openExplorer(tx.hash)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tx.kindLabel)
                        .notebookHeadline(15)
                        .foregroundStyle(AppTheme.ink)
                    Text(tx.amount)
                        .notebookBody(14)
                        .foregroundStyle(
                            tx.amount.hasPrefix("+") ? AppTheme.positive : AppTheme.ink.opacity(0.8)
                        )
                    if let counterparty = tx.counterparty {
                        Text(counterparty)
                            .notebookCaption(11)
                            .foregroundStyle(AppTheme.ink.opacity(0.45))
                    }
                    Text(tx.shortHash)
                        .font(NotebookFont.caption(10))
                        .monospaced()
                        .foregroundStyle(AppTheme.ink.opacity(0.35))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(relativeTime(tx.timestamp))
                        .notebookCaption(11)
                        .foregroundStyle(AppTheme.ink.opacity(0.45))
                    Text(tx.status)
                        .notebookCaption(11)
                        .foregroundStyle(tx.status == "成功" ? AppTheme.positive : AppTheme.negative)
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 14, variant: .mint, tilt: 0.3)
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func loadTransactions() async {
        guard ChainConfig.usesTestnet,
              let address = walletSession.account?.address else {
            transactions = []
            loadError = "請先建立錢包並使用 Sepolia 測試網"
            return
        }

        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            transactions = try await SepoliaExplorerService.transactions(
                for: holding.id,
                walletAddress: address
            )
        } catch {
            loadError = error.localizedDescription
            transactions = []
        }
    }

    private func openExplorer(_ hash: String) {
        guard let url = URL(string: "\(ChainConfig.active.explorerURL)/tx/\(hash)") else { return }
        UIApplication.shared.open(url)
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return "\(max(1, Int(interval / 60))) 分鐘前" }
        if interval < 86_400 { return "\(Int(interval / 3600)) 小時前" }
        return "\(Int(interval / 86_400)) 天前"
    }
}
