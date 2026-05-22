import SwiftUI

struct ExploreView: View {
    @Environment(WalletSession.self) private var walletSession
    @State private var urlText = "https://app.uniswap.org"
    @State private var browserDestination: BrowserDestination?
    @State private var showNeedWallet = false
    @State private var explorePath = NavigationPath()
    @State private var blockedURLMessage: String?
    @Environment(\.colorScheme) private var colorScheme

    private let categories = MockExploreDataService().categories()

    var body: some View {
        NavigationStack(path: $explorePath) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    BNBChainBadge()
                    walletConnectCard
                    integrationCheckCard
                    urlBar
                    ForEach(categories) { category in
                        categorySection(category)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .vibeNotebookPage(colorScheme: colorScheme, deckInset: false)
            .navigationTitle("探索")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(item: $browserDestination) { dest in
                if let address = walletSession.account?.address {
                    DAppBrowserView(
                        initialURL: dest.url,
                        walletAddress: address,
                        chainIdHex: ChainConfig.active.chainIdHex
                    )
                    .vibePresentedScreen()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationDestination(for: ExploreRoute.self) { route in
                switch route {
                case .pufferStaking:
                    PufferStakingView()
                case .bitrefillShop(let query, let previewProducts):
                    BitrefillShopView(initialQuery: query, previewProducts: previewProducts) { productId in
                        explorePath.append(ExploreRoute.bitrefillProduct(productId: productId))
                    }
                    .subpageNavigation(backTitle: "探索")
                case .bitrefillProduct(let productId):
                    BitrefillProductDetailView(productId: productId) { invoice in
                        explorePath.append(ExploreRoute.bitrefillCheckout(invoice: invoice))
                    }
                    .subpageNavigation(backTitle: "商店")
                case .bitrefillCheckout(let invoice):
                    BitrefillCheckoutView(invoice: invoice)
                        .subpageNavigation(backTitle: "確認")
                }
            }
            .alert("請先建立錢包", isPresented: $showNeedWallet) {
                Button("了解", role: .cancel) {}
            } message: {
                Text("需先建立或匯入錢包，才能連接 Sepolia Dapp。")
            }
            .alert("已阻擋可疑連結", isPresented: Binding(
                get: { blockedURLMessage != nil },
                set: { if !$0 { blockedURLMessage = nil } }
            )) {
                Button("了解", role: .cancel) {}
            } message: {
                Text(blockedURLMessage ?? "")
            }
            .vibeNavigationPathAnimation(explorePath)
        }
    }

    private var integrationCheckCard: some View {
        NavigationLink {
            IntegrationCheckView()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                SketchIcon(kind: .gear, size: 22, color: AppTheme.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("一鍵檢測 GitHub 整合")
                        .notebookHeadline(16)
                        .foregroundStyle(AppTheme.ink)
                    Text("展開每項可見逐步檢測：Token Core、惡意連結、Face ID…")
                        .notebookCaption(12)
                        .foregroundStyle(AppTheme.ink.opacity(0.55))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.ink.opacity(0.35))
            }
            .padding(16)
            .glassCard(cornerRadius: 16, variant: .pink)
        }
        .buttonStyle(.plain)
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
                        if SepoliaFaucetOpener.isGoogleSepoliaFaucetURLString(dapp.url) {
                            openGoogleSepoliaFaucet()
                        } else {
                            urlText = dapp.url
                            openDapp(dapp.url)
                        }
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

    private func openGoogleSepoliaFaucet() {
        guard walletSession.hasWallet, walletSession.account != nil else {
            showNeedWallet = true
            return
        }
        SepoliaFaucetOpener.openGoogleFaucet(copyingAddress: walletSession.account?.address)
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
        let verdict = WalletURLSafety.evaluate(url)
        guard verdict.allowed else {
            blockedURLMessage = "檢測到可疑網址，已阻擋開啟。\n原因：\(verdict.reason)"
            return
        }
        if SepoliaFaucetOpener.isGoogleSepoliaFaucetURL(url) {
            openGoogleSepoliaFaucet()
            return
        }
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
