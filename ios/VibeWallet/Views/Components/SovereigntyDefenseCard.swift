import SwiftUI

struct SovereigntyDefenseCard: View {
    let status: SovereigntyStatus
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            scoreRing
            HStack(spacing: 12) {
                DefensePillar(
                    title: "Secure Enclave",
                    stateTitle: status.biometric.title,
                    subtitle: status.biometric.subtitle,
                    icon: "lock.shield.fill",
                    isActive: status.biometric == .active,
                    accent: AppTheme.primary
                )
                DefensePillar(
                    title: "備份守護者",
                    stateTitle: status.backupGuardian.title,
                    subtitle: status.backupGuardian.subtitle,
                    icon: "person.3.fill",
                    isActive: status.backupGuardian == .fullyProtected,
                    accent: status.backupGuardian == .fullyProtected
                        ? AppTheme.positive
                        : AppTheme.warning
                )
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 12, variant: .pink, tilt: -0.4)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("主權防衛狀態")
                    .font(.headline.weight(.bold))
                Text("你的金鑰與恢復路徑，始終由你掌控")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: status.isDefenseOptimal ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                .font(.title2)
                .foregroundStyle(
                    status.isDefenseOptimal ? AppTheme.positive : AppTheme.warning
                )
        }
    }

    private var scoreRing: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(status.defenseScore) / 100)
                    .stroke(
                        AppTheme.meshAccent,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text("\(status.defenseScore)")
                    .font(.title2.weight(.bold).monospacedDigit())
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text("防衛指數")
                    .font(.subheadline.weight(.semibold))
                Text(defenseMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    private var defenseMessage: String {
        if status.isDefenseOptimal {
            return "生物防護與社交恢復均已就緒，主權防線完整。"
        }
        if status.biometric == .active {
            return "生物防護已啟用；建議完成備份守護者以提升恢復韌性。"
        }
        return "建議啟用 Secure Enclave 並配置備份守護者。"
    }
}

private struct DefensePillar: View {
    let title: String
    let stateTitle: String
    let subtitle: String
    let icon: String
    let isActive: Bool
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Text(stateTitle)
                .font(.footnote.weight(.bold))

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                Circle()
                    .fill(isActive ? AppTheme.positive : AppTheme.warning)
                    .frame(width: 6, height: 6)
                Text(isActive ? "已啟用" : "待加強")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isActive ? AppTheme.positive : AppTheme.warning)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(accent.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    SovereigntyDefenseCard(status: MockHomeDataService().loadSovereigntyStatus())
        .padding()
        .preferredColorScheme(.dark)
}
