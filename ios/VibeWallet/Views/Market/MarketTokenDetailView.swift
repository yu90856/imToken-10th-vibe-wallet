import SwiftUI

struct MarketTokenDetailView: View {
    let token: MarketToken
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appNavigation) private var appNavigation

    @State private var timeframe: MarketChartTimeframe = .m15
    @State private var chartPack = MarketChartSeriesService.mockSeries(for: "ethereum", timeframe: .m15)
    @State private var isLoadingChart = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                chartSection
                priceHeader
                timeframePicker
                actionsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
        .navigationTitle(token.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: timeframe) {
            await loadChart()
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            NotebookPencilChartView(pack: chartPack, timeframe: timeframe)
                .frame(maxWidth: .infinity)
            if isLoadingChart {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
            Text("橫軸：時間 · 縱軸：價格（USD）· \(timeframe.label)")
                .notebookCaption(11)
                .foregroundStyle(AppTheme.ink.opacity(0.5))
        }
    }

    private var priceHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(token.symbol)
                    .notebookHeadline(24)
                Text(token.name)
                    .notebookCaption(14)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(token.formattedPrice)
                    .font(NotebookFont.largeAmount(28))
                Text(String(format: "%+.2f%%", chartPack.changePct))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(chartPack.changePct >= 0 ? AppTheme.positive : AppTheme.negative)
            }
            Text("區間最高 \(formatUSD(chartPack.high)) · 最低 \(formatUSD(chartPack.low))")
                .notebookCaption(12)
                .foregroundStyle(.secondary)
        }
    }

    private var timeframePicker: some View {
        HStack(spacing: 8) {
            ForEach(MarketChartTimeframe.allCases) { tf in
                let active = tf == timeframe
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { timeframe = tf }
                } label: {
                    Text(tf.label)
                        .font(.subheadline.weight(active ? .semibold : .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .strokeBorder(
                                    active ? AppTheme.primary : AppTheme.cardStroke(for: colorScheme),
                                    lineWidth: 1.5
                                )
                                .background(
                                    Capsule().fill(active ? AppTheme.stickyNoteFill(for: colorScheme) : .clear)
                                )
                        )
                        .foregroundStyle(active ? AppTheme.ink : AppTheme.ink.opacity(0.65))
                        .rotationEffect(.degrees(active ? -1 : 0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("操作")
                .notebookHeadline(16)
            Button {
                appNavigation.openSwap(preselectedTo: token)
            } label: {
                HStack {
                    SketchIcon(kind: .swap, size: 20, color: .white)
                    Text("交換 \(token.symbol)")
                        .notebookHeadline(16)
                    Spacer()
                    Text("→")
                }
                .foregroundStyle(.white)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.heroGradient)
                )
            }
            .buttonStyle(.plain)

            if token.category == .onChain, !token.contractAddress.isEmpty {
                Text("合約 \(token.shortContract)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Text("行情僅供參考；非鏈上代幣對可能無法直接鏈上交換。")
                .notebookCaption(11)
                .foregroundStyle(AppTheme.ink.opacity(0.55))
        }
        .padding(16)
        .glassCard(cornerRadius: 14)
    }

    @MainActor
    private func loadChart() async {
        isLoadingChart = true
        chartPack = await MarketChartSeriesService.loadSeries(tokenId: token.id, timeframe: timeframe)
        isLoadingChart = false
    }

    private func formatUSD(_ value: Double) -> String {
        if value < 0.01 { return String(format: "$%.5f", value) }
        if value < 1 { return String(format: "$%.4f", value) }
        return String(format: "$%.2f", value)
    }
}
