import SwiftUI

/// 脅迫模式下偽裝的系統錯誤（不洩漏求救意圖）
struct DuressFakeErrorOverlay: View {
    @Bindable var duress = DuressModeController.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.warning)

                Text("應用程式出現錯誤請稍後再試…")
                    .notebookHeadline(17)
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.center)

                if duress.fakeErrorSecondsLeft > 0 {
                    Text("\(duress.fakeErrorSecondsLeft) 秒後可繼續")
                        .notebookCaption(13)
                        .foregroundStyle(AppTheme.ink.opacity(0.55))
                }

                Button {
                    duress.confirmFakeErrorTapped()
                } label: {
                    Text("確認")
                        .notebookHeadline(16)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppTheme.heroGradient)
                        )
                }
            }
            .padding(24)
            .frame(maxWidth: 300)
            .glassCard(cornerRadius: 16, variant: .yellow, tilt: 0)
        }
    }
}
