import SwiftUI

struct BitrefillOrderStatusView: View {
    let invoiceId: String
    let orderId: String?
    let initialRedemption: BitrefillRedemptionInfo?

    @Environment(\.colorScheme) private var colorScheme
    @State private var invoiceStatus = ""
    @State private var paymentStatus = ""
    @State private var redemption: BitrefillRedemptionInfo?
    @State private var isLoading = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("訂單編號")
                    .notebookCaption(11)
                    .foregroundStyle(AppTheme.ink.opacity(0.5))
                Text(invoiceId)
                    .font(NotebookFont.caption(11))
                    .monospaced()

                if isLoading {
                    Text("查詢中…")
                        .notebookBody(14)
                } else {
                    Text("發票：\(invoiceStatus)")
                        .notebookBody(14)
                    Text("付款：\(paymentStatus)")
                        .notebookBody(14)
                }

                if let redemption {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("禮品卡 / 兌換碼")
                            .notebookHeadline(17)
                        if let code = redemption.code {
                            Text(code)
                                .font(NotebookFont.largeAmount(20))
                                .monospaced()
                                .textSelection(.enabled)
                            Button {
                                UIPasteboard.general.string = code
                            } label: {
                                Text("複製兌換碼")
                                    .notebookCaption(12)
                                    .foregroundStyle(AppTheme.primary)
                            }
                            .buttonStyle(.plain)
                        }
                        if let link = redemption.link, let url = URL(string: link) {
                            Link("開啟兌換連結", destination: url)
                                .font(.caption.weight(.semibold))
                        }
                        if let instructions = redemption.instructions {
                            Text(instructions)
                                .notebookCaption(12)
                                .foregroundStyle(AppTheme.ink.opacity(0.6))
                        }
                    }
                    .padding(16)
                    .glassCard(cornerRadius: 16, variant: .mint)
                } else if !isLoading {
                    Text("付款確認後，兌換碼會出現在這裡。可下拉重新整理。")
                        .notebookCaption(12)
                        .foregroundStyle(AppTheme.ink.opacity(0.55))
                }
            }
            .padding(20)
        }
        .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
        .navigationTitle("訂單狀態")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await poll() }
        .task {
            redemption = initialRedemption
            await poll()
        }
    }

    @MainActor
    private func poll() async {
        isLoading = true
        defer { isLoading = false }
        if case .success(let invoice) = await BitrefillCommerceService.fetchInvoice(id: invoiceId) {
            invoiceStatus = invoice.status
            paymentStatus = invoice.paymentStatus ?? "—"
            if let orderId = invoice.orderId ?? orderId {
                if case .success(let info) = await BitrefillCommerceService.fetchRedemption(orderId: orderId) {
                    redemption = info
                }
            }
        }
    }
}
