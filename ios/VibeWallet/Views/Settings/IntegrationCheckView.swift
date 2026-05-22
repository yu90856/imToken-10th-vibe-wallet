import SwiftUI

/// 評審／開發者：一鍵檢測 GitHub 開源元件與 API 是否實際被 App 使用
struct IntegrationCheckView: View {
    @Environment(WalletSession.self) private var walletSession
    @Environment(\.colorScheme) private var colorScheme

    @State private var results: [HackathonIntegrationCheck.Result] = []
    @State private var isRunning = false
    @State private var lastRunAt: Date?
    @State private var expandedIDs: Set<String> = []
    @State private var notificationTestMessage: String?
    @State private var notificationTestBusy = false
    @State private var widgetPreviewSnapshot = WidgetDataStore.load()

    private var passCount: Int { results.filter { $0.status == .pass }.count }
    private var failCount: Int { results.filter { $0.status == .fail }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryCard

                notificationTestSection

                widgetPreviewSection

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

                Text("點任一項目可展開，查看逐步檢測過程（含安全、惡意連結規則等）。")
                    .notebookCaption(12)
                    .foregroundStyle(AppTheme.ink.opacity(0.55))

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

    private var notificationTestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("通知測試（獨立）")
                .notebookHeadline(17)

            Text("點下方按鈕後，約 5 秒會送出本地推播。請立刻按 Home 鍵回到 iPhone 桌面等待；點通知應跳轉到錢包或 Bitrefill 商店。")
                .notebookBody(13)
                .foregroundStyle(AppTheme.ink.opacity(0.65))

            ForEach(NotificationTestBench.Kind.allCases) { kind in
                Button {
                    Task { await runNotificationTest(kind) }
                } label: {
                    HStack {
                        Text(kind.title)
                            .notebookHeadline(15)
                        Spacer()
                        if notificationTestBusy {
                            ProgressView()
                        }
                    }
                    .foregroundStyle(AppTheme.ink)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .disabled(notificationTestBusy)

                Text(kind.instruction)
                    .notebookCaption(11)
                    .foregroundStyle(AppTheme.ink.opacity(0.5))
            }

            if let notificationTestMessage {
                Text(notificationTestMessage)
                    .notebookCaption(12)
                    .foregroundStyle(AppTheme.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 16, variant: .pink)
    }

    private var widgetPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("桌面小工具預覽")
                .notebookHeadline(17)

            Text("Widget 需在實機主畫面長按 → 「+」→ 搜尋 Vibe Wallet → 選「Vibe 快覽」。Xcode 預覽請切換 scheme 為 VibeWalletWidgetExtension，或看下方模擬版面。")
                .notebookBody(13)
                .foregroundStyle(AppTheme.ink.opacity(0.65))

            WidgetPreviewCard(
                snapshot: widgetPreviewSnapshot.marketRows.isEmpty
                    ? WidgetPreviewCard.sample
                    : widgetPreviewSnapshot
            )

            Button {
                Task {
                    await WidgetSyncService.refreshFromApp()
                    widgetPreviewSnapshot = WidgetDataStore.load()
                }
            } label: {
                Text("同步 Widget 資料")
                    .notebookHeadline(15)
                    .foregroundStyle(AppTheme.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 16, variant: .yellow)
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
        let isExpanded = expandedIDs.contains(item.id)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    if isExpanded {
                        expandedIDs.remove(item.id)
                    } else {
                        expandedIDs.insert(item.id)
                    }
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    statusIcon(item.status)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.title)
                                .notebookHeadline(15)
                                .foregroundStyle(AppTheme.ink)
                            Spacer(minLength: 0)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.ink.opacity(0.35))
                        }
                        Text(item.repo)
                            .notebookCaption(11)
                            .foregroundStyle(AppTheme.primary)
                        Text(item.detail)
                            .notebookCaption(12)
                            .foregroundStyle(AppTheme.ink.opacity(0.6))
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(item.steps) { step in
                        stepRow(step)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .glassCard(cornerRadius: 14)
    }

    private func stepRow(_ step: HackathonIntegrationCheck.CheckStep) -> some View {
        HStack(alignment: .top, spacing: 10) {
            stepIcon(step.status)
                .font(.caption)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .notebookBody(13)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.ink)
                Text(step.detail)
                    .notebookCaption(11)
                    .foregroundStyle(AppTheme.ink.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.ink.opacity(0.04))
        )
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

    @ViewBuilder
    private func stepIcon(_ status: HackathonIntegrationCheck.CheckStep.StepStatus) -> some View {
        switch status {
        case .pass:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.positive)
        case .fail:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(AppTheme.negative)
        case .info:
            Image(systemName: "circle")
                .foregroundStyle(AppTheme.ink.opacity(0.3))
        }
    }

    @MainActor
    private func runChecks() async {
        isRunning = true
        results = await HackathonIntegrationCheck.runAll(hasWallet: walletSession.hasWallet)
        lastRunAt = Date()
        isRunning = false
        widgetPreviewSnapshot = WidgetDataStore.load()
    }

    @MainActor
    private func runNotificationTest(_ kind: NotificationTestBench.Kind) async {
        notificationTestBusy = true
        notificationTestMessage = await NotificationTestBench.schedule(kind)
        notificationTestBusy = false
    }
}

#Preview {
    NavigationStack {
        IntegrationCheckView()
            .environment(WalletSession.shared)
    }
}
