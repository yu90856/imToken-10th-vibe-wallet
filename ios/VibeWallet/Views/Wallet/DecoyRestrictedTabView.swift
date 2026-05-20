import SwiftUI

/// 脅迫模式下非錢包分頁的佔位，避免顯示真實資產
struct DecoyRestrictedTabView: View {
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            SketchIcon(kind: .lock, size: 40, color: AppTheme.ink.opacity(0.35))
            Text(title)
                .notebookHeadline(20)
                .foregroundStyle(AppTheme.ink.opacity(0.5))
            Text("目前為安全顯示模式")
                .notebookCaption(12)
                .foregroundStyle(AppTheme.ink.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
    }
}

struct DecoySwapPlaceholderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var amount = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("交換")
                    .notebookTitle(28)
                    .foregroundStyle(AppTheme.ink)
                Text("目前無可用餘額進行交換。")
                    .notebookBody(15)
                    .foregroundStyle(AppTheme.ink.opacity(0.55))

                TextField("輸入數量試算", text: $amount)
                    .keyboardType(.decimalPad)
                    .font(NotebookFont.body(15))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppTheme.stickyNoteFill(for: colorScheme))
                    )

                Button(action: attemptSwap) {
                    Text("預覽交換")
                        .notebookHeadline(16)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.heroGradient)
                        )
                }
                .disabled(amount.isEmpty)
            }
            .padding(20)
        }
        .walletDeckScrollInset()
        .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
    }

    private func attemptSwap() {
        Task { @MainActor in
            DuressModeController.shared.recordHostileAction()
        }
    }
}
