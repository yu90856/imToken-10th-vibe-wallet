import SwiftUI

struct BitrefillShopView: View {
    let initialQuery: String
    let previewProducts: [BitrefillProductMatch]
    var onSelectProduct: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText: String
    @State private var products: [BitrefillProductMatch] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchedQuery: String?
    @State private var showsPreviewBanner = false

    init(
        initialQuery: String = "",
        previewProducts: [BitrefillProductMatch] = [],
        onSelectProduct: @escaping (String) -> Void = { _ in }
    ) {
        self.initialQuery = initialQuery
        self.previewProducts = previewProducts
        self.onSelectProduct = onSelectProduct
        _searchText = State(initialValue: initialQuery)
        let trimmed = initialQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !previewProducts.isEmpty, !trimmed.isEmpty {
            _products = State(initialValue: previewProducts)
            _searchedQuery = State(initialValue: trimmed)
            _showsPreviewBanner = State(initialValue: true)
        }
    }

    var body: some View {
        shopScrollContent
            .vibeNotebookPage(colorScheme: colorScheme, deckInset: false)
            .navigationTitle("Bitrefill 商店")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                let trimmed = initialQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                // 首頁已帶 preview 時先顯示縮圖，避免一進店就重打 API 蓋掉或閃爍
                if previewProducts.isEmpty {
                    await runSearch()
                }
            }
    }

    private var shopScrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: VibeSpacing.medium) {
                searchBar
                statusSection
                productList
                footerNote
            }
            .padding(.horizontal, VibeSpacing.mediumLarge)
            .padding(.vertical, VibeSpacing.medium)
        }
    }

    private var searchBar: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.small) {
            VibeSectionHeader(title: "搜尋禮品卡、eSIM、充值", systemImage: "magnifyingglass")
            HStack(spacing: VibeSpacing.small) {
                VibeTextField(placeholder: "例如 Amazon、eSIM、Steam", text: $searchText)
                    .submitLabel(.search)
                    .onSubmit { Task { await runSearch() } }

                Button {
                    Task { await runSearch() }
                } label: {
                    Text("搜尋")
                        .frame(minWidth: 56)
                }
                .buttonStyle(VibePrimaryButtonStyle())
                .disabled(isLoading)
                .frame(width: 88)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16, variant: .mint)
    }

    @ViewBuilder
    private var statusSection: some View {
        if isLoading {
            Text("正在向 Bitrefill 搜尋…")
                .notebookBody(14)
                .foregroundStyle(AppTheme.ink.opacity(0.55))
        } else if let errorMessage {
            Text(errorMessage)
                .notebookCaption(12)
                .foregroundStyle(AppTheme.ink.opacity(0.65))
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 14, variant: .yellow)
        } else if let searchedQuery, products.isEmpty {
            ContentUnavailableView.search(text: searchedQuery)
                .padding(.vertical, VibeSpacing.medium)
        } else if let searchedQuery {
            VStack(alignment: .leading, spacing: 6) {
                if showsPreviewBanner {
                    Text("來自首頁購物清單的預覽結果（含商品圖）")
                        .notebookCaption(11)
                        .foregroundStyle(AppTheme.primary)
                }
                Text("「\(searchedQuery)」共 \(products.count) 項 · 點擊進入詳情")
                    .notebookCaption(12)
                    .foregroundStyle(AppTheme.ink.opacity(0.5))
            }
        }
    }

    @ViewBuilder
    private var productList: some View {
        ForEach(products) { product in
            Button {
                onSelectProduct(product.id)
            } label: {
                productRow(product)
            }
            .buttonStyle(.plain)
        }
    }

    private func productRow(_ product: BitrefillProductMatch) -> some View {
        HStack(alignment: .top, spacing: 14) {
            BitrefillProductImageView(
                productId: product.id,
                imageURL: product.imageURL,
                size: 56,
                cornerRadius: 12
            )
            VStack(alignment: .leading, spacing: 8) {
                Text(product.name)
                    .notebookHeadline(16)
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.leading)
                if !product.countryName.isEmpty {
                    Text(product.countryName)
                        .notebookCaption(12)
                        .foregroundStyle(AppTheme.ink.opacity(0.55))
                }
                HStack {
                    Text(product.inStock ? "有貨" : "缺貨")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(product.inStock ? AppTheme.positive : AppTheme.ink.opacity(0.5))
                    Spacer()
                    Text("詳情 →")
                        .notebookCaption(11)
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16, variant: .pink)
    }

    private var footerNote: some View {
        Text("在 App 內選面額、建立 Bitrefill 訂單，並可用錢包簽署主網 ETH 付款（測試商品建議用小面額）。")
            .notebookCaption(11)
            .foregroundStyle(AppTheme.ink.opacity(0.45))
            .padding(.horizontal, 4)
    }

    @MainActor
    private func runSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            errorMessage = "請輸入搜尋關鍵字"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        switch await BitrefillCatalogService.search(query: query, limit: 20) {
        case .success(let list):
            products = list
            searchedQuery = query
            showsPreviewBanner = false
        case .failure(let error):
            if products.isEmpty {
                searchedQuery = query
                errorMessage = error.localizedDescription
            } else {
                // 保留首頁預覽列表與縮圖，僅提示 API 問題
                errorMessage = "無法更新搜尋：\(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    NavigationStack {
        BitrefillShopView(
            initialQuery: "eSIM",
            previewProducts: [
                BitrefillProductMatch(
                    id: "test-gift-card-link",
                    name: "Demo Gift Card",
                    countryName: "Global",
                    inStock: true,
                    imageURL: BitrefillProductImageURLs.resolved(
                        productId: "test-gift-card-link",
                        apiImage: nil
                    )
                ),
            ]
        )
    }
}
