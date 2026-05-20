import SwiftUI

struct HotNewsStickyCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var items: [CryptoHotNewsItem] = []
    @State private var expandedID: String?
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("熱門消息")
                    .notebookHeadline(17)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text(isLoading ? "載入中" : "即時")
                    .notebookCaption(11)
                    .foregroundStyle(AppTheme.ink.opacity(0.45))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().strokeBorder(AppTheme.ink.opacity(0.15), lineWidth: 1))
            }

            if items.isEmpty && isLoading {
                Text("正在取得幣圈新聞…")
                    .notebookBody(14)
                    .foregroundStyle(AppTheme.ink.opacity(0.5))
            } else if items.isEmpty {
                Text("暫時無法載入新聞")
                    .notebookBody(14)
                    .foregroundStyle(AppTheme.ink.opacity(0.5))
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider().opacity(0.35)
                    }
                    newsRow(item)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16, variant: .pink, tilt: -0.7)
        .task { await loadNews() }
    }

    @MainActor
    private func loadNews() async {
        isLoading = true
        items = await CryptoNewsService.fetchRecentNews(limit: 3)
        isLoading = false
    }

    private func newsRow(_ item: CryptoHotNewsItem) -> some View {
        let isExpanded = expandedID == item.id
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    expandedID = isExpanded ? nil : item.id
                }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("\(indexBadge(for: item))")
                                .notebookCaption(10)
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(AppTheme.primary.opacity(0.85)))

                            Text(item.title)
                                .notebookHeadline(15)
                                .foregroundStyle(AppTheme.ink)
                                .multilineTextAlignment(.leading)
                        }

                        Text(item.summary)
                            .notebookBody(13)
                            .foregroundStyle(AppTheme.ink.opacity(0.65))
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 10) {
                            Text(item.relativeTimeLabel)
                            Text("🔥 \(formatDiscussion(item.discussionScore))")
                            Text(item.source)
                        }
                        .notebookCaption(11)
                        .foregroundStyle(AppTheme.ink.opacity(0.45))
                    }
                    Spacer(minLength: 4)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.primary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(item.body)
                    .notebookBody(13)
                    .foregroundStyle(AppTheme.ink.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                if let link = item.articleURL, let url = URL(string: link) {
                    Link("閱讀原文", destination: url)
                        .notebookCaption(12)
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .accessibilityHint(isExpanded ? "點擊收合" : "點擊展開全文")
    }

    private func indexBadge(for item: CryptoHotNewsItem) -> String {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return "·" }
        return "\(idx + 1)"
    }

    private func formatDiscussion(_ score: Int) -> String {
        if score >= 1000 { return String(format: "%.1fK", Double(score) / 1000) }
        return "\(score)"
    }
}

#Preview {
    HotNewsStickyCard()
        .padding()
}
