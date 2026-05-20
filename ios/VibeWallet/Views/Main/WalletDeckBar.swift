import SwiftUI

/// 常駐底部導覽：首頁 · 行情 · 交換 · 探索 · 錢包（底圖為整條直尺橫幅）
struct WalletDeckBar: View {
    @Binding var selection: AppTab
    var onSelect: ((AppTab) -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    private let iconSize: CGFloat = 24
    private let swapCircleSize: CGFloat = 44

    var body: some View {
        HStack(spacing: 0) {
            deckItem(tab: .home, kind: .home, label: "首頁")
            deckItem(tab: .market, kind: .market, label: "行情")
            swapDeckItem
            deckItem(tab: .explore, kind: .explore, label: "探索")
            deckItem(tab: .wallet, kind: .wallet, label: "錢包")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .background {
            DeckRulerBackground()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(AppTheme.pencil.opacity(colorScheme == .dark ? 0.45 : 0.35), lineWidth: 1.2)
                )
                .shadow(color: AppTheme.ink.opacity(0.14), radius: 10, y: 3)
        }
        .padding(.bottom, 6)
    }

    private func select(_ tab: AppTab) {
        onSelect?(tab)
        if tab != .home {
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = tab
            }
        }
    }

    private var swapDeckItem: some View {
        let isSelected = selection == .swap
        return Button {
            select(.swap)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? AnyShapeStyle(AppTheme.heroGradient)
                                : AnyShapeStyle(AppTheme.pencil.opacity(0.55))
                        )
                        .frame(width: swapCircleSize, height: swapCircleSize)
                        .overlay(
                            Circle()
                                .strokeBorder(AppTheme.ink.opacity(0.22), lineWidth: 1)
                        )
                    SketchIcon(kind: .swap, size: 22, color: .white)
                }
                Text("交換")
                    .font(NotebookFont.label(11))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(isSelected ? AppTheme.primary : AppTheme.ink.opacity(0.6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("交換")
    }

    private func deckItem(tab: AppTab, kind: SketchIcon.Kind, label: String) -> some View {
        let isSelected = selection == tab
        return Button {
            select(tab)
        } label: {
            VStack(spacing: 4) {
                SketchIcon(
                    kind: kind,
                    size: iconSize,
                    color: isSelected ? AppTheme.primary : AppTheme.ink.opacity(0.5)
                )
                Text(label)
                    .font(NotebookFont.label(11))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(isSelected ? AppTheme.primary : AppTheme.ink.opacity(0.6))
        }
        .buttonStyle(.plain)
    }
}

enum WalletDeckMetrics {
    /// 底部 Deck 佔用高度（含安全區），避免 ScrollView 最後一項被遮住
    static let bottomInset: CGFloat = 88
}

extension View {
    /// 為可捲動內容預留 Deck 空間
    func walletDeckScrollInset() -> some View {
        contentMargins(.bottom, WalletDeckMetrics.bottomInset, for: .scrollContent)
    }
}
