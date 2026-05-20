import SwiftUI

/// 評審／開發者：一鍵檢測 GitHub 開源元件與 API 是否實際被 App 使用
struct IntegrationCheckView: View {
    @Environment(WalletSession.self) private var walletSession
    @Environment(\.colorScheme) private var colorScheme

    @State private var results: [HackathonIntegrationCheck.Result] = []
    @State private var isRunning = false
    @State private var lastRunAt: Date?

    private var passCount: Int { results.filter { $0.status == .pass }.count }
    private var failCount: Int { results.filter { $0.status == .fail }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryCard

                Button {
                    Task { await runChecks() }
                } label: {
                    HStack {
                        if isRunning {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isRunning ? "檢測中…" : "一鍵檢測全部功能")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.heroGradient)
                    )
                }
                .disabled(isRunning)

                if let lastRunAt {
                    Text("上次檢測：\(lastRunAt.formatted(date: .omitted, time: .shortened))")
                        .notebookCaption(11)
                        .foregroundStyle(AppTheme.ink.opacity(0.5))
                }

                ForEach(results) { item in
                    resultRow(item)
                }

                if results.isEmpty && !isRunning {
                    Text("點擊上方按鈕開始檢測。通過項目會標示為綠色，供評審確認本專案已串接 Token Core、CoinGecko、DApp 瀏覽器等。")
                        .notebookBody(13)
                        .foregroundStyle(AppTheme.ink.opacity(0.6))
                }
            }
            .padding(20)
        }
        .walletDeckScrollInset()
        .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
        .navigationTitle("功能檢測")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if results.isEmpty {
                await runChecks()
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("參賽功能自檢")
                .notebookHeadline(17)
            if results.isEmpty {
                Text("驗證 @consenlabs/tcx-wasm、CoinGecko、CryptoCompare、Sepolia Dapp 等是否可用。")
                    .notebookBody(13)
                    .foregroundStyle(AppTheme.ink.opacity(0.65))
            } else {
                HStack(spacing: 16) {
                    Label("\(passCount) 通過", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.positive)
                    if failCount > 0 {
                        Label("\(failCount) 失敗", systemImage: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.negative)
                    }
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 16, variant: .mint)
    }

    private func resultRow(_ item: HackathonIntegrationCheck.Result) -> some View {
        HStack(alignment: .top, spacing: 12) {
            statusIcon(item.status)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .notebookHeadline(15)
                    .foregroundStyle(AppTheme.ink)
                Text(item.repo)
                    .notebookCaption(11)
                    .foregroundStyle(AppTheme.primary)
                Text(item.detail)
                    .notebookCaption(12)
                    .foregroundStyle(AppTheme.ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassCard(cornerRadius: 14)
    }

    @ViewBuilder
    private func statusIcon(_ status: HackathonIntegrationCheck.Result.Status) -> some View {
        switch status {
        case .pass:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.positive)
                .font(.title2)
        case .fail:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(AppTheme.negative)
                .font(.title2)
        case .info:
            Image(systemName: "info.circle.fill")
                .foregroundStyle(AppTheme.ink.opacity(0.35))
                .font(.title2)
        }
    }

    @MainActor
    private func runChecks() async {
        isRunning = true
        results = await HackathonIntegrationCheck.runAll(hasWallet: walletSession.hasWallet)
        lastRunAt = Date()
        isRunning = false
    }
}

#Preview {
    NavigationStack {
        IntegrationCheckView()
            .environment(WalletSession.shared)
    }
}
