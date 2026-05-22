import SwiftUI
import WidgetKit

struct VibeWalletGlanceWidget: Widget {
    let kind = "VibeWalletGlanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VibeWidgetProvider()) { entry in
            VibeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 252 / 255, green: 248 / 255, blue: 236 / 255)
                }
        }
        .configurationDisplayName("Vibe 快覽")
        .description("行情走勢與 Bitrefill 熱門商品")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct VibeWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct VibeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> VibeWidgetEntry {
        VibeWidgetEntry(date: Date(), snapshot: sampleSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (VibeWidgetEntry) -> Void) {
        completion(VibeWidgetEntry(date: Date(), snapshot: WidgetDataStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VibeWidgetEntry>) -> Void) {
        let snapshot = WidgetDataStore.load()
        let entry = VibeWidgetEntry(date: Date(), snapshot: snapshot)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private var sampleSnapshot: WidgetSnapshot {
        WidgetSnapshot(
            updatedAt: Date(),
            marketRows: [
                WidgetMarketRow(id: "btc", symbol: "BTC", priceText: "$64,200", changeText: "+1.2%", changeIsPositive: true),
                WidgetMarketRow(id: "eth", symbol: "ETH", priceText: "$3,420", changeText: "-0.4%", changeIsPositive: false),
            ],
            bitrefillRows: [
                WidgetBitrefillRow(id: "1", name: "Amazon Gift Card", countryName: "US", searchQuery: "amazon"),
            ]
        )
    }
}

struct VibeWidgetEntryView: View {
    let entry: VibeWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("vibe note")
                    .font(.custom("Bradley Hand", size: 18))
                    .foregroundStyle(Color(red: 45 / 255, green: 42 / 255, blue: 38 / 255))
                Spacer()
                Text(updatedLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 12) {
                marketColumn
                Divider()
                bitrefillColumn
            }
        }
        .padding(14)
    }

    private var updatedLabel: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: entry.snapshot.updatedAt)
    }

    private var marketColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("行情")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 75 / 255, green: 110 / 255, blue: 145 / 255))
            if entry.snapshot.marketRows.isEmpty {
                Text("開啟 App 同步")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.snapshot.marketRows.prefix(4)) { row in
                    HStack {
                        Text(row.symbol)
                            .font(.caption.weight(.bold))
                        Spacer()
                        Text(row.priceText)
                            .font(.caption2.monospacedDigit())
                        Text(row.changeText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(row.changeIsPositive ? Color.green : Color.red)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bitrefillColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bitrefill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 75 / 255, green: 110 / 255, blue: 145 / 255))
            if entry.snapshot.bitrefillRows.isEmpty {
                Text("尚無推薦")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.snapshot.bitrefillRows.prefix(3)) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.name)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(row.countryName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// 預覽方式：Xcode 左上角 scheme 選「VibeWalletWidgetExtension」→ 打開本檔 Preview。
// 主 App scheme 無法預覽 Widget；請到「設定 → 功能檢測」看 WidgetPreviewCard。

#Preview("Vibe 快覽 · 中", as: .systemMedium) {
    VibeWalletGlanceWidget()
} timeline: {
    VibeWidgetEntry(date: .now, snapshot: WidgetSnapshot(
        updatedAt: .now,
        marketRows: [
            WidgetMarketRow(id: "btc", symbol: "BTC", priceText: "$64,200", changeText: "+1.2%", changeIsPositive: true),
            WidgetMarketRow(id: "eth", symbol: "ETH", priceText: "$3,400", changeText: "+2.1%", changeIsPositive: true),
        ],
        bitrefillRows: [
            WidgetBitrefillRow(id: "a", name: "Steam", countryName: "Global", searchQuery: "steam"),
            WidgetBitrefillRow(id: "b", name: "Amazon", countryName: "US", searchQuery: "amazon"),
        ]
    ))
}

#Preview("Vibe 快覽 · 大", as: .systemLarge) {
    VibeWalletGlanceWidget()
} timeline: {
    VibeWidgetEntry(date: .now, snapshot: WidgetSnapshot(
        updatedAt: .now,
        marketRows: [
            WidgetMarketRow(id: "eth", symbol: "ETH", priceText: "$3,400", changeText: "+2.1%", changeIsPositive: true),
        ],
        bitrefillRows: [
            WidgetBitrefillRow(id: "a", name: "Steam", countryName: "Global", searchQuery: "steam"),
        ]
    ))
}
