import Foundation

enum BitrefillPaymentError: LocalizedError {
    case walletNotReady
    case unsupportedCurrency(String)
    case insufficientMainnetETH(required: Decimal, available: Decimal)

    var errorDescription: String? {
        switch self {
        case .walletNotReady:
            return "請先建立錢包並解鎖"
        case .unsupportedCurrency(let c):
            return "此訂單付款幣種暫不支援 App 內簽名：\(c)"
        case .insufficientMainnetETH(let required, let available):
            let need = NSDecimalNumber(decimal: required).stringValue
            let have = NSDecimalNumber(decimal: available).stringValue
            return "主網 ETH 不足。需約 \(need) ETH，目前 \(have) ETH"
        }
    }
}

/// 使用 Token Core 向 Bitrefill 發票地址支付（以太坊主網）
enum BitrefillPaymentService {
    private static let mainnet = ChainConfig.ethereumMainnet

    static func sendEthereumInvoicePayment(
        walletAddress: String,
        keystoreJSON: String,
        password: String,
        invoice: BitrefillInvoiceSummary
    ) async throws -> String {
        guard invoice.paymentMethod.lowercased() == "ethereum",
              let to = invoice.paymentAddress,
              let wei = invoice.paymentAmountWei else {
            throw BitrefillPaymentError.unsupportedCurrency(invoice.paymentCurrency ?? invoice.paymentMethod)
        }

        let required = EVMWeiFormatter.weiToEther(wei)
        let balance = try await ChainRPCClient.fetchNativeBalance(address: walletAddress, chain: mainnet)
        let gasPrice = try await ChainRPCClient.fetchGasPrice(rpcURL: mainnet.rpcURL)
        let gasLimit = try await ChainRPCClient.estimateGas(
            from: walletAddress,
            to: to,
            valueWei: wei,
            rpcURL: mainnet.rpcURL
        )
        let gasCost = EVMWeiFormatter.weiToEther(gasPrice * gasLimit)
        guard balance >= required + gasCost else {
            throw BitrefillPaymentError.insufficientMainnetETH(required: required + gasCost, available: balance)
        }

        let nonce = try await ChainRPCClient.fetchTransactionCount(address: walletAddress, rpcURL: mainnet.rpcURL)
        let signed = try await TokenCoreService.signEthereumLegacyTransaction(
            keystoreJSON: keystoreJSON,
            password: password,
            to: to,
            valueWei: wei,
            nonce: nonce,
            gasLimit: gasLimit,
            gasPrice: gasPrice,
            chainId: mainnet.id
        )
        return try await ChainRPCClient.sendRawTransaction(
            signedRaw: signed.rawTransaction,
            rpcURL: mainnet.rpcURL
        )
    }
}
