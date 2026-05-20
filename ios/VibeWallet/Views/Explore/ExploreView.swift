import SwiftUI

struct ExploreView: View {
    @Environment(WalletSession.self) private var walletSession
    @State private var urlText = "https://app.uniswap.org"
    @State private var browserDestination: BrowserDestination?
    @State private var showNeedWallet = false
    @Environment(\.colorScheme) private var colorScheme

    private let categories = MockExploreDataService().categories()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    BNBChainBadge()
                    walletConnectCard
                    sepoliaDappQuickCard
                    urlBar
                    ForEach(categories) { category in
                        categorySection(category)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle("探索")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(item: $browserDestination) { dest in
                if let address = walletSession.account?.address {
                    DAppBrowserView(
                        initialURL: dest.url,
                        walletAddress: address,
                        chainIdHex: ChainConfig.active.chainIdHex
                    )
                }
            }
            .alert("請先建立錢包", isPresented: $showNeedWallet) {
                Button("了解", role: .cancel) {}
            } message: {
                Text("需先建立或匯入錢包，才能連接 Sepolia Dapp。")
            }
        }
    }

    private var sepoliaDappQuickCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sepolia 可測 Dapp")
                .notebookHeadline(17)

            Text("內建瀏覽器注入錢包，連上 Sepolia 後可測兌換、NFT 與領取測試 ETH。")
                .notebookCaption(12)
                .foregroundStyle(AppTheme.ink.opacity(0.6))

            HStack(spacing: 8) {
                quickDappButton(title: "Uniswap", url: "https://app.uniswap.org")
                quickDappButton(title: "1inch", url: "https://app.1inch.io")
            }
            HStack(spacing: 8) {
                quickDappButton(title: "thirdweb", url: "https://thirdweb.com/dashboard")
                quickDappButton(title: "Etherscan", url: "https://sepolia.etherscan.io")
            }
            HStack(spacing: 8) {
                quickDappButton(title: "領水", url: ChainConfig.testnetFaucetURL.absoluteString)
                quickDappButton(title: "Chainlink", url: "https://faucets.chain.link/sepolia")
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16, variant: .mint)
    }

    private func quickDappButton(title: String, url: String) -> some View {
        Button {
            openDapp(url)
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(AppTheme.primary)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(AppTheme.primary, lineWidth: 1)
                )
        }
    }

    private var walletConnectCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SketchIcon(kind: .link, size: 18, color: AppTheme.primary)
                Text("錢包連線狀態")
                    .notebookHeadline(17)
            }
            if walletSession.hasWallet, let account = walletSession.account {
                Text(account.address)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
                Text("\(ChainConfig.active.name) · 已就緒 · 內建瀏覽器可連 Dapp")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.positive)
            } else {
                Text("尚未連接鏈上錢包")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(cornerRadius: 16)
    }

    private var urlBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                SketchIcon(kind: .explore, size: 20, color: AppTheme.primary)
                TextField("輸入 Dapp 網址", text: $urlText)
                    .font(NotebookFont.body(16))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
            )

            Button {
                openDapp(urlText)
            } label: {
                Text("在 App 內開啟並連線")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ExplorePrimaryButtonStyle())
        }
    }

    private func categorySection(_ category: ExploreCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category.title)
                .font(.headline.weight(.bold))
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12
            ) {
                ForEach(category.items) { dapp in
                    Button {
                        urlText = dapp.url
                        openDapp(dapp.url)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(dapp.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                            Text(dapp.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .glassCard(cornerRadius: 14)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func openDapp(_ raw: String) {
        guard walletSession.hasWallet, walletSession.account != nil else {
            showNeedWallet = true
            return
        }
        var next = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if next.isEmpty { return }
        if !next.lowercased().hasPrefix("http") {
            next = "https://\(next)"
        }
        guard let url = URL(string: next) else { return }
        urlText = next
        browserDestination = BrowserDestination(url: url)
    }
}

private struct BrowserDestination: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ExplorePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.heroGradient)
                    .opacity(configuration.isPressed ? 0.85 : 1)
            )
    }
}

#Preview {
    ExploreView()
        .environment(WalletSession.shared)
}
