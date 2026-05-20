import SwiftUI

/// 主權密鑰安全中心 — 筆記本手繪風，呼應 Passkey + AA 架構
struct PasskeySecureStatusView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable private var security = SecuritySettingsStore.shared

    @State private var breathe = false

    private var isActive: Bool {
        security.faceIDEnabled && TransactionAuthService.canUseBiometry
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    SketchIcon(kind: .lock, size: 36, color: AppTheme.ink)
                    Circle()
                        .fill(isActive ? AppTheme.positive : AppTheme.ink.opacity(0.25))
                        .frame(width: 10, height: 10)
                        .offset(x: 14, y: -14)
                        .opacity(isActive ? (breathe ? 1 : 0.45) : 0.6)
                        .shadow(color: isActive ? AppTheme.positive.opacity(0.5) : .clear, radius: breathe ? 6 : 2)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text("主權密鑰安全中心")
                        .notebookHeadline(17)
                        .foregroundStyle(AppTheme.ink)

                    statusPill
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                statusRow("密鑰位置", "Apple Secure Enclave (secp256r1)")
                statusRow("備份鏈", "iCloud 端到端加密同步中")
                statusRow("資產載體", "ERC-4337 / ERC-7579 智能合約（Sepolia）")
            }

            Text(
                "您的私鑰由 iPhone 晶片自主保管，任何第三方（包含本 App）皆無法觸及。"
                + "用 Apple 的硬體主權，解鎖 Web3 的資產主權。"
            )
            .notebookBody(12)
            .foregroundStyle(AppTheme.ink.opacity(0.65))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassCard(cornerRadius: 18, variant: .yellow, tilt: 1.2)
        .onAppear {
            guard isActive else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }

    private var statusPill: some View {
        Text(isActive ? "Passkey 硬體級自託管已啟用" : "於設定開啟 Face ID 以啟用")
            .notebookCaption(11)
            .foregroundStyle(isActive ? AppTheme.positive : AppTheme.ink.opacity(0.55))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .strokeBorder(
                        isActive ? AppTheme.positive.opacity(0.5) : AppTheme.ink.opacity(0.2),
                        lineWidth: 1
                    )
            )
    }

    private func statusRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .notebookCaption(11)
                .foregroundStyle(AppTheme.ink.opacity(0.45))
                .frame(width: 56, alignment: .leading)
            Text(value)
                .notebookBody(12)
                .foregroundStyle(AppTheme.ink.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    PasskeySecureStatusView()
        .padding()
        .background(AppTheme.pageBackground(for: .light))
}
