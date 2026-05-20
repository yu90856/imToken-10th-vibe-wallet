import SwiftUI

struct SwapTokenPickerSheet: View {
    let title: String
    let tokens: [MarketToken]
    let selectedID: String?
    let onSelect: (MarketToken) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [MarketToken] {
        tokens.filter { $0.matchesSearch(query) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { token in
                Button {
                    onSelect(token)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        TokenLogoView(tokenId: token.id, symbol: token.symbol, imageURL: token.imageURL, size: 36)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(token.symbol)
                                .font(.headline.weight(.semibold))
                            Text(token.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(token.shortContract)
                                .font(.caption2.monospaced())
                                .foregroundStyle(Color.secondary.opacity(0.8))
                        }
                        Spacer()
                        if token.id == selectedID {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.primary)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "搜尋代幣")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
