import SwiftUI
import UIKit

enum SepoliaFaucetOpener {
    static let copiedAddressMessage = "已複製錢包地址，請在 Google 頁面貼上領水。"

    @MainActor
    static func openGoogleFaucet(copyingAddress address: String?) {
        if let trimmed = address?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            UIPasteboard.general.string = trimmed
        }
        Task {
            await UIApplication.shared.open(ChainConfig.testnetFaucetURL)
        }
    }

    static func isGoogleSepoliaFaucetURL(_ url: URL) -> Bool {
        url.host == ChainConfig.testnetFaucetURL.host
            && url.path == ChainConfig.testnetFaucetURL.path
    }

    static func isGoogleSepoliaFaucetURLString(_ raw: String) -> Bool {
        guard let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return isGoogleSepoliaFaucetURL(url)
    }
}

struct GoogleSepoliaFaucetButton: View {
    let address: String?
    var title: String = "用 Google 帳號領水"
    var compact = false
    var action: (() -> Void)?

    var body: some View {
        Button {
            if let action {
                action()
            } else {
                SepoliaFaucetOpener.openGoogleFaucet(copyingAddress: address)
            }
        } label: {
            HStack(spacing: 6) {
                SketchIcon(kind: .drop, size: compact ? 16 : 18, color: AppTheme.primary)
                Text(title)
                    .font(compact ? NotebookFont.caption(12) : NotebookFont.headline(16))
            }
            .frame(maxWidth: compact ? nil : .infinity)
            .padding(.vertical, compact ? 8 : 12)
            .foregroundStyle(compact ? AppTheme.primary : .white)
            .background(buttonBackground)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var buttonBackground: some View {
        if compact {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(AppTheme.primary, lineWidth: 1)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.heroGradient)
        }
    }
}

struct GoogleSepoliaFaucetSheet: View {
    let address: String
    var onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                SketchIcon(kind: .drop, size: 44, color: AppTheme.primary)

                Text("領取 Sepolia 測試 ETH")
                    .notebookTitle(24)
                    .foregroundStyle(AppTheme.ink(for: colorScheme))

                Text("使用 Google 帳號登入 Google Cloud 水龍頭即可領水。已複製你的錢包地址，請在網頁上貼上。")
                    .notebookBody(16)
                    .foregroundStyle(AppTheme.secondaryInk(for: colorScheme))

                Text(address)
                    .font(.caption.monospaced())
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.stickyNoteFill(for: colorScheme))
                    )

                GoogleSepoliaFaucetButton(
                    address: address,
                    title: "去 Google 領 Sepolia 測試 ETH"
                )

                Button("稍後再領", role: .cancel) {
                    onDismiss()
                }
                .frame(maxWidth: .infinity)
                .notebookHeadline(16)
                .foregroundStyle(AppTheme.secondaryInk(for: colorScheme))

                Spacer(minLength: 0)
            }
            .padding(24)
            .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Sepolia 領水")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") { onDismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .vibePresentedScreen()
    }
}
