import SwiftUI

struct WalletTransferSheet: View {
    enum Mode {
        case send
        case receive
    }

    let mode: Mode
    var isDecoy: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(WalletSession.self) private var walletSession

    @State private var toAddress = ""
    @State private var amount = ""
    @State private var sent = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if mode == .receive {
                    receiveContent
                } else {
                    sendContent
                }
                Spacer()
            }
            .padding(24)
            .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle(mode == .send ? "發送" : "接收")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var displayAddress: String {
        if isDecoy { return MockDuressWalletData.fakeAddress }
        return walletSession.account?.address ?? "尚未建立錢包"
    }

    private var receiveContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("掃描或複製地址以接收資產")
                .notebookBody(14)
                .foregroundStyle(AppTheme.ink.opacity(0.65))

            Text(displayAddress)
                .font(NotebookFont.caption(12))
                .monospaced()
                .foregroundStyle(AppTheme.ink)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 12, variant: .yellow)

            Button {
                UIPasteboard.general.string = displayAddress
            } label: {
                Text("複製地址")
                    .notebookHeadline(16)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.heroGradient))
            }
        }
    }

    private var sendContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if sent {
                Text(isDecoy ? "已送出（示範）" : "交易已提交（示範，未廣播鏈上）")
                    .notebookHeadline(17)
                    .foregroundStyle(AppTheme.positive)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("收款地址")
                    .notebookCaption(12)
                TextField("0x…", text: $toAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(NotebookFont.body(15))
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.stickyNoteFill(for: colorScheme)))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("數量")
                    .notebookCaption(12)
                TextField("0.0", text: $amount)
                    .keyboardType(.decimalPad)
                    .font(NotebookFont.body(15))
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.stickyNoteFill(for: colorScheme)))
            }

            Button(action: submitSend) {
                Text("確認發送")
                    .notebookHeadline(16)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.heroGradient))
            }
            .disabled(toAddress.isEmpty || amount.isEmpty)
        }
    }

    private func submitSend() {
        if isDecoy {
            Task { @MainActor in
                DuressModeController.shared.recordHostileAction()
            }
            return
        }
        sent = true
    }
}
