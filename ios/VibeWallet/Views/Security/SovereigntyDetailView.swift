import SwiftUI

struct SovereigntyDetailView: View {
    let initialStatus: SovereigntyStatus
    @State private var biometricEnabled: Bool
    @State private var guardianCount: Int
    @Environment(\.colorScheme) private var colorScheme
    @State private var alertMessage: String?
    @State private var showAlert = false

    init(status: SovereigntyStatus) {
        initialStatus = status
        _biometricEnabled = State(initialValue: status.biometric == .active)
        _guardianCount = State(initialValue: Self.guardianCount(from: status.backupGuardian))
    }

    private static func guardianCount(from state: BackupGuardianState) -> Int {
        switch state {
        case .fullyProtected: return 3
        case .partial: return 1
        case .notConfigured: return 0
        }
    }

    private var defenseScore: Int {
        let bio = biometricEnabled ? 45 : 0
        let guardScore = min(guardianCount, 3) * 18
        return min(100, bio + guardScore + 4)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("防衛指數")
                    Spacer()
                    Text("\(defenseScore)")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(AppTheme.primary)
                }
            }

            Section("Secure Enclave · 生物防護") {
                Toggle(isOn: $biometricEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Face ID 解鎖金鑰")
                            .font(.subheadline.weight(.semibold))
                        Text("金鑰儲存於 Secure Enclave，生物特徵不離開裝置")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: biometricEnabled) { _, on in
                    showFeedback(on ? "已啟用生物防護（示範）" : "已關閉生物防護（示範）")
                }
            }

            Section("備份守護者 · 社交恢復") {
                Stepper(
                    "已設定守護者：\(guardianCount) / 3",
                    value: $guardianCount,
                    in: 0...3
                )
                .onChange(of: guardianCount) { _, count in
                    showFeedback("守護者數量已更新為 \(count)/3（示範）")
                }

                if guardianCount < 3 {
                    Button {
                        guardianCount = min(3, guardianCount + 1)
                        showFeedback("已新增一位守護者（示範）")
                    } label: {
                        Label("新增守護者", systemImage: "person.badge.plus")
                    }
                }

                Text("守護者無法單獨轉走資產；僅在你授權的恢復流程中協助。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("主權原則") {
                sovereigntyRow(
                    icon: "key.fill",
                    title: "金鑰在本機",
                    detail: "助記詞由 Token Core 加密，不傳送至雲端"
                )
                sovereigntyRow(
                    icon: "signature",
                    title: "你親自簽名",
                    detail: "每筆鏈上操作需明確確認，助理僅提供解讀"
                )
                sovereigntyRow(
                    icon: "network",
                    title: "建議使用測試網",
                    detail: "示範與開發請優先 Sepolia / Base Sepolia"
                )
            }
        }
        .navigationTitle("主權防衛")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppTheme.pageBackground(for: colorScheme).ignoresSafeArea())
        .alert("已更新", isPresented: $showAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func sovereigntyRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.primary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func showFeedback(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

#Preview {
    NavigationStack {
        SovereigntyDetailView(status: MockHomeDataService().loadSovereigntyStatus())
    }
}
