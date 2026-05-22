import SwiftUI

struct TestnetBanner: View {
    let address: String?

    private var chain: EVMChain { ChainConfig.active }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SketchIcon(kind: .shield, size: 20, color: AppTheme.warning)
                Text("Ethereum Sepolia")
                    .notebookHeadline(17)
                    .foregroundStyle(AppTheme.warning)
            }

            Text("測試網 chainId \(chain.id)。請用 Sepolia ETH，勿轉入主網資產。")
                .notebookCaption(12)
                .foregroundStyle(AppTheme.ink.opacity(0.65))

            if let address {
                Text(address)
                    .font(NotebookFont.caption(11))
                    .monospaced()
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            GoogleSepoliaFaucetButton(
                address: address,
                title: "領取 Sepolia ETH（Google Cloud）",
                compact: true
            )

            ForEach(Array(ChainConfig.testnetFaucetAlternates.enumerated()), id: \.offset) { index, url in
                Link(destination: url) {
                    HStack(spacing: 6) {
                        SketchIcon(kind: .link, size: 14, color: AppTheme.primary)
                        Text("備用水龍頭 \(index + 1)")
                            .notebookCaption(11)
                    }
                }
            }

            if let address, let explorer = explorerAddressURL(address) {
                Link(destination: explorer) {
                    HStack(spacing: 6) {
                        SketchIcon(kind: .link, size: 14, color: AppTheme.primary)
                        Text("在 Etherscan Sepolia 查看地址")
                            .notebookCaption(11)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 14)
    }

    private func explorerAddressURL(_ address: String) -> URL? {
        URL(string: "\(chain.explorerURL)/address/\(address)")
    }
}
