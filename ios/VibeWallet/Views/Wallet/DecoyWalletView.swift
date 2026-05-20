import SwiftUI

/// 脅迫模式假錢包：餘額 0、假地址與假交易紀錄
struct DecoyWalletView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var path = NavigationPath()
    @State private var copiedAddress = false
    @State private var showSend = false
    @State private var showReceive = false

    private let portfolio = MockDuressWalletData.zeroPortfolio
    private let holdings = MockDuressWalletData.zeroHoldings

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    totalCard
                    holdingsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .walletDeckScrollInset()
            .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle("錢包")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: WalletRoute.self) { route in
                if case .tokenHistory(let tokenId) = route,
                   let holding = holdings.first(where: { $0.id == tokenId }) {
                    DecoyTokenTransactionHistoryView(holding: holding)
                }
            }
            .sheet(isPresented: $showSend) {
                WalletTransferSheet(mode: .send, isDecoy: true)
            }
            .sheet(isPresented: $showReceive) {
                WalletTransferSheet(mode: .receive, isDecoy: true)
            }
        }
    }

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("總資產")
                    .notebookHeadline(17)
                    .foregroundStyle(AppTheme.ink.opacity(0.7))
                Spacer()
                BNBChainBadge(compact: true)
            }

            Text("$0.00")
                .font(NotebookFont.largeAmount(36))
                .foregroundStyle(AppTheme.ink)

            HStack(spacing: 10) {
                transferButton(title: "發送", icon: "arrow.up.right") { showSend = true }
                transferButton(title: "接收", icon: "arrow.down.left") { showReceive = true }
            }
            .padding(.top, 4)

            Divider().opacity(0.35)

            HStack {
                Text(MockDuressWalletData.fakeShortAddress)
                    .font(NotebookFont.caption(11))
                    .monospaced()
                    .foregroundStyle(AppTheme.ink.opacity(0.5))
                Spacer()
                Button {
                    UIPasteboard.general.string = MockDuressWalletData.fakeAddress
                    copiedAddress = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedAddress = false }
                } label: {
                    HStack(spacing: 4) {
                        SketchIcon(kind: .copy, size: 14, color: AppTheme.primary)
                        Text(copiedAddress ? "已複製" : "複製")
                            .notebookCaption(11)
                    }
                }
                .foregroundStyle(AppTheme.primary)
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 16, variant: .yellow, tilt: 0.5)
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

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("我的代幣")
                .notebookHeadline(17)
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, 4)

            ForEach(holdings) { holding in
                Button {
                    path.append(WalletRoute.tokenHistory(holding.id))
                } label: {
                    HStack(spacing: 14) {
                        TokenLogoView(tokenId: holding.id, symbol: holding.symbol, imageURL: holding.imageURL, size: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(holding.name)
                                .notebookHeadline(16)
                            Text("0 \(holding.symbol)")
                                .notebookCaption(12)
                                .foregroundStyle(AppTheme.ink.opacity(0.55))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("$0")
                                .notebookHeadline(15)
                            Text("交易紀錄 →")
                                .notebookCaption(11)
                                .foregroundStyle(AppTheme.primary)
                        }
                    }
                    .padding(14)
                    .glassCard(cornerRadius: 16, variant: .pink, tilt: -0.5)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct DecoyTokenTransactionHistoryView: View {
    let holding: HoldingAsset
    @Environment(\.colorScheme) private var colorScheme
    @State private var transactions: [TokenTransaction] = []

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text(holding.symbol)
                    .notebookTitle(24)
                Text("0 \(holding.symbol) · $0")
                    .notebookBody(14)
                    .foregroundStyle(AppTheme.ink.opacity(0.6))

                ForEach(transactions) { tx in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tx.kindLabel)
                                .notebookHeadline(15)
                            Text(tx.amount)
                                .notebookBody(14)
                            Text(tx.counterparty ?? "")
                                .notebookCaption(11)
                                .foregroundStyle(AppTheme.ink.opacity(0.45))
                        }
                        Spacer()
                        Text(tx.status)
                            .notebookCaption(11)
                            .foregroundStyle(AppTheme.positive)
                    }
                    .padding(14)
                    .glassCard(cornerRadius: 14, variant: .mint)
                }
            }
            .padding(20)
        }
        .walletDeckScrollInset()
        .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
        .navigationTitle("交易紀錄")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            transactions = MockDuressWalletData.fakeTransactions(forTokenId: holding.id)
        }
    }
}
