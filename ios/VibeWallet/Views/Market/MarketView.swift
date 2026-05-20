import SwiftUI

struct MarketView: View {
    @State private var viewModel = MarketViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appNavigation) private var appNavigation

    var body: some View {
        @Bindable var appNavigation = appNavigation
        NavigationStack(path: $appNavigation.marketPath) {
            VStack(spacing: 0) {
                searchBar
                marketStatusBanner
                segmentBanner
                sortBar
                tokenList
            }
            .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle("行情")
            .navigationBarTitleDisplayMode(.large)
            .task { await viewModel.refreshMarket() }
            .refreshable { await viewModel.refreshMarket(force: true) }
            .overlay(alignment: .top) {
                if viewModel.isLoadingMarket {
                    ProgressView()
                        .padding(.top, 8)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            SketchIcon(kind: .search, size: 20, color: AppTheme.ink.opacity(0.5))
            TextField("搜尋代幣名稱或合約地址", text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var marketStatusBanner: some View {
        Text(viewModel.marketStatusText)
            .font(.caption2)
            .foregroundStyle(AppTheme.ink.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
    }

    private var segmentBanner: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MarketSegment.allCases) { segment in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.segment = segment
                        }
                    } label: {
                        Text(segment.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(
                                    viewModel.segment == segment
                                        ? AnyShapeStyle(AppTheme.heroGradient)
                                        : AnyShapeStyle(
                                            colorScheme == .dark
                                                ? Color.white.opacity(0.08)
                                                : Color.black.opacity(0.06)
                                        )
                                )
                            )
                            .foregroundStyle(
                                viewModel.segment == segment ? Color.white : .primary
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 10)
    }

    private var sortBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MarketSortOption.allCases) { option in
                    Button {
                        viewModel.toggleSort(option)
                    } label: {
                        Text(viewModel.sortLabel(for: option))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().strokeBorder(
                                    viewModel.sortOption == option
                                        ? AppTheme.primary
                                        : AppTheme.cardStroke(for: colorScheme),
                                    lineWidth: 1
                                )
                            )
                            .foregroundStyle(
                                viewModel.sortOption == option ? AppTheme.primary : .secondary
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var tokenList: some View {
        if viewModel.isWatchlistEmpty {
            VStack(spacing: 12) {
                Image(systemName: "star")
                    .font(.largeTitle)
                    .foregroundStyle(Color.secondary)
                Text("尚無關注代幣")
                    .font(.headline)
                Text("點擊列表左側星號加入關注清單")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(viewModel.displayedTokens) { token in
                    HStack(spacing: 0) {
                        Button {
                            viewModel.toggleWatchlist(token)
                        } label: {
                            SketchIcon(
                                kind: .star,
                                size: 22,
                                color: viewModel.isWatchlisted(token) ? AppTheme.warning : AppTheme.ink.opacity(0.35)
                            )
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)

                        Button {
                            appNavigation.openSwap(preselectedTo: token)
                        } label: {
                            MarketTokenRowContent(token: token)
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Color.secondary.opacity(0.35))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .walletDeckScrollInset()
        }
    }
}

#Preview {
    MarketView()
}
