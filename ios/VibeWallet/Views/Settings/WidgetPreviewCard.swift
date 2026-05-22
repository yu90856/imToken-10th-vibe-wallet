import SwiftUI

/// 主 App 內預覽 Widget 版面（無需切換 Widget Extension scheme）
struct WidgetPreviewCard: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("vibe note")
                    .notebookHeadline(18)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text(updatedLabel)
                    .notebookCaption(11)
                    .foregroundStyle(AppTheme.ink.opacity(0.45))
            }

            HStack(alignment: .top, spacing: 12) {
                marketColumn
                Divider().opacity(0.35)
                bitrefillColumn
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.paperLight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.ink.opacity(0.08), lineWidth: 1)
        )
    }

    private var updatedLabel: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: snapshot.updatedAt)
    }

    private var marketColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("行情")
                .notebookCaption(12)
                .foregroundStyle(AppTheme.primary)
            if snapshot.marketRows.isEmpty {
                Text("開啟 App 同步")
                    .notebookCaption(11)
                    .foregroundStyle(AppTheme.ink.opacity(0.45))
            } else {
                ForEach(snapshot.marketRows.prefix(4)) { row in
                    HStack {
                        Text(row.symbol)
                            .notebookHeadline(13)
                        Spacer()
                        Text(row.priceText)
                            .notebookCaption(11)
                        Text(row.changeText)
                            .notebookCaption(11)
                            .foregroundStyle(row.changeIsPositive ? AppTheme.positive : AppTheme.negative)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bitrefillColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bitrefill")
                .notebookCaption(12)
                .foregroundStyle(AppTheme.primary)
            if snapshot.bitrefillRows.isEmpty {
                Text("尚無推薦")
                    .notebookCaption(11)
                    .foregroundStyle(AppTheme.ink.opacity(0.45))
            } else {
                ForEach(snapshot.bitrefillRows.prefix(3)) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.name)
                            .notebookHeadline(13)
                            .lineLimit(1)
                        Text(row.countryName)
                            .notebookCaption(11)
                            .foregroundStyle(AppTheme.ink.opacity(0.5))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static var sample: WidgetSnapshot {
        WidgetSnapshot(
            updatedAt: Date(),
            marketRows: [
                WidgetMarketRow(id: "btc", symbol: "BTC", priceText: "$64,200", changeText: "+1.2%", changeIsPositive: true),
                WidgetMarketRow(id: "eth", symbol: "ETH", priceText: "$3,420", changeText: "-0.4%", changeIsPositive: false),
            ],
            bitrefillRows: [
                WidgetBitrefillRow(id: "1", name: "Amazon Gift Card", countryName: "US", searchQuery: "amazon"),
                WidgetBitrefillRow(id: "2", name: "Steam", countryName: "Global", searchQuery: "steam"),
            ]
        )
    }
}
