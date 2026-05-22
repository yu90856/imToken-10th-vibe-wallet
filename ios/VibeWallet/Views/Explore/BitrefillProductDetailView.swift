import SwiftUI
import UIKit

struct BitrefillProductDetailView: View {
    let productId: String
    var onCheckout: (BitrefillInvoiceSummary) -> Void

    @Environment(WalletSession.self) private var walletSession
    @Environment(\.colorScheme) private var colorScheme

    @State private var product: BitrefillProductDetail?
    @State private var selectedPackage: BitrefillPackageOption?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isCreatingOrder = false
    @State private var showNeedWallet = false
    @State private var showPIN = false
    @State private var showWalletPassword = false
    @State private var alertMessage: String?
    @State private var termsExpanded = false

    private var showsCheckoutBar: Bool {
        product != nil && errorMessage == nil && !isLoading
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        Text("載入商品…")
                            .notebookBody(14)
                            .foregroundStyle(AppTheme.ink.opacity(0.55))
                    } else if let errorMessage {
                        Text(errorMessage)
                            .notebookCaption(12)
                            .foregroundStyle(AppTheme.ink.opacity(0.65))
                            .padding(16)
                            .glassCard(cornerRadius: 14, variant: .yellow)
                    } else if let product {
                        productHeader(product)
                        packagesSection(product)
                        termsSection(product)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, showsCheckoutBar ? 100 : 16)
            }
            .walletDeckScrollInset()

            if showsCheckoutBar, let product {
                checkoutBar(product)
            }
        }
        .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
        .navigationTitle(product?.name ?? "商品詳情")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadProduct() }
        .alert("Bitrefill", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("了解", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .alert("請先建立錢包", isPresented: $showNeedWallet) {
            Button("了解", role: .cancel) {}
        } message: {
            Text("建立或匯入錢包後才能下單。")
        }
        .sheet(isPresented: $showPIN) {
            TransactionPINEntrySheet(mode: .verify) { success in
                showPIN = false
                if success { continueAfterTxAuth() }
            }
        }
        .sheet(isPresented: $showWalletPassword) {
            WalletPasswordSheet(
                onUnlocked: {
                    showWalletPassword = false
                    Task { await createOrderAndCheckout() }
                },
                onCancel: { showWalletPassword = false }
            )
        }
    }

    private func productHeader(_ product: BitrefillProductDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                BitrefillProductImageView(
                    productId: product.id,
                    imageURL: product.imageURL,
                    size: 72,
                    cornerRadius: 14
                )
                VStack(alignment: .leading, spacing: 6) {
                    Text(product.name)
                        .notebookTitle(22)
                    if !product.countryName.isEmpty {
                        Text(product.countryName)
                            .notebookCaption(12)
                            .foregroundStyle(AppTheme.ink.opacity(0.55))
                    }
                    Text(product.inStock ? "有庫存" : "暫時缺貨")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(product.inStock ? AppTheme.positive : AppTheme.ink.opacity(0.5))
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16, variant: .mint)
    }

    private func packagesSection(_ product: BitrefillProductDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("選擇面額")
                .notebookHeadline(16)
            if product.packages.isEmpty {
                Text("此商品無固定面額，請稍後再試。")
                    .notebookCaption(12)
            } else {
                ForEach(product.packages) { pkg in
                    Button {
                        selectedPackage = pkg
                    } label: {
                        HStack {
                            Text("$\(pkg.value) \(product.currency)")
                                .notebookHeadline(15)
                            Spacer()
                            if selectedPackage?.id == pkg.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.primary)
                            }
                        }
                        .padding(14)
                        .glassCard(
                            cornerRadius: 14,
                            variant: selectedPackage?.id == pkg.id ? .yellow : .pink,
                            tilt: 0.2
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func termsSection(_ product: BitrefillProductDetail) -> some View {
        if let raw = product.terms, !raw.isEmpty {
            let plain = Self.plainTerms(from: raw)
            if !plain.isEmpty {
                DisclosureGroup(isExpanded: $termsExpanded) {
                    Text(plain)
                        .notebookCaption(11)
                        .foregroundStyle(AppTheme.ink.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                } label: {
                    Text("使用條款與說明")
                        .notebookCaption(12)
                        .foregroundStyle(AppTheme.ink.opacity(0.6))
                }
                .padding(14)
                .glassCard(cornerRadius: 14, variant: .yellow, tilt: 0.1)
            }
        }
    }

    private func checkoutBar(_ product: BitrefillProductDetail) -> some View {
        VStack(spacing: 8) {
            if product.packages.isEmpty {
                Text("此商品暫無可購面額")
                    .notebookCaption(11)
                    .foregroundStyle(AppTheme.ink.opacity(0.55))
            } else if selectedPackage == nil {
                Text("請先選擇面額")
                    .notebookCaption(11)
                    .foregroundStyle(AppTheme.ink.opacity(0.55))
            }
            buyButton(product)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background {
            AppTheme.pageBackground(for: colorScheme)
                .opacity(0.97)
                .shadow(color: AppTheme.ink.opacity(0.08), radius: 8, y: -4)
                .ignoresSafeArea(edges: .bottom)
        }
        .padding(.bottom, WalletDeckMetrics.bottomInset)
    }

    private func canPlaceOrder(_ product: BitrefillProductDetail) -> Bool {
        product.inStock && selectedPackage != nil && !product.packages.isEmpty
    }

    private func buyButton(_ product: BitrefillProductDetail) -> some View {
        Button {
            beginCheckout()
        } label: {
            Text(isCreatingOrder ? "建立訂單中…" : "建立訂單並付款")
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canPlaceOrder(product) ? AnyShapeStyle(AppTheme.heroGradient) : AnyShapeStyle(AppTheme.ink.opacity(0.3)))
                )
        }
        .disabled(isCreatingOrder || !canPlaceOrder(product))
    }

    private static func plainTerms(from html: String) -> String {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("<") else { return trimmed }
        guard let data = trimmed.data(using: .utf8),
              let attributed = try? NSAttributedString(
                  data: data,
                  options: [
                      .documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue,
                  ],
                  documentAttributes: nil
              ) else {
            return fallbackPlainTerms(from: trimmed)
        }
        let lines = attributed.string
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let text = lines.joined(separator: "\n")
        return text.isEmpty ? fallbackPlainTerms(from: trimmed) : text
    }

    private static func fallbackPlainTerms(from html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    private func loadProduct() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        switch await BitrefillCommerceService.fetchProduct(id: productId) {
        case .success(let detail):
            product = detail
            selectedPackage = detail.packages.first
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func beginCheckout() {
        guard walletSession.hasWallet, walletSession.account != nil else {
            showNeedWallet = true
            return
        }
        Task { @MainActor in
            do {
                switch try await SigningUnlockCoordinator.prepareForSigning(reason: "確認 Bitrefill 購買") {
                case .readyToSign:
                    await createOrderAndCheckout()
                case .needWalletPassword:
                    showWalletPassword = true
                }
            } catch TransactionAuthError.pinRequired {
                showPIN = true
            } catch TransactionAuthError.pinNotSet {
                alertMessage = TransactionAuthError.pinNotSet.localizedDescription
            } catch {
                if !(error is TransactionAuthError) {
                    alertMessage = error.localizedDescription
                }
            }
        }
    }

    @MainActor
    private func continueAfterTxAuth() {
        Task {
            switch try? await SigningUnlockCoordinator.prepareForSigning(reason: "解鎖以建立 Bitrefill 訂單") {
            case .readyToSign:
                await createOrderAndCheckout()
            case .needWalletPassword, .none:
                showWalletPassword = true
            }
        }
    }

    @MainActor
    private func createOrderAndCheckout() async {
        guard let pkg = selectedPackage,
              let address = walletSession.account?.address else { return }
        isCreatingOrder = true
        defer { isCreatingOrder = false }

        switch await BitrefillCommerceService.createInvoice(
            productId: productId,
            packageId: pkg.id,
            refundAddress: address
        ) {
        case .success(let invoice):
            onCheckout(invoice)
        case .failure(let error):
            alertMessage = error.localizedDescription
        }
    }
}
