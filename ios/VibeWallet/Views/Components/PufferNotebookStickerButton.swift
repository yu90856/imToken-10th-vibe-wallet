import SwiftUI

/// 首頁便條紙上的河豚圖案：僅顯示魚體、點擊撕起動畫後導向質押（返回首頁仍可再點）
struct PufferNotebookStickerButton: View {
    var onPeelComplete: () -> Void

    @State private var isPeeling = false

    private let fishSize: CGFloat = 85
    private let restRotation: Double = -14
    private let peelRotation: Double = -38

    var body: some View {
        Button(action: peelSticker) {
            pufferFishGraphic
        }
        .buttonStyle(.plain)
        .disabled(isPeeling)
        .accessibilityLabel("Puffer 質押管理")
        .accessibilityHint("點擊撕下貼紙並開啟質押頁")
    }

    /// 僅顯示河豚圖案（完整保留邊緣，避免圓形裁切切到魚鰭）
    private var pufferFishGraphic: some View {
        Image("PufferNotebookSticker")
            .resizable()
            .scaledToFit()
            .frame(width: fishSize, height: fishSize)
            .shadow(color: .black.opacity(0.14), radius: 6, x: 2, y: 4)
            .rotationEffect(.degrees(isPeeling ? peelRotation : restRotation))
            .scaleEffect(isPeeling ? 0.55 : 1, anchor: .center)
            .offset(
                x: isPeeling ? 28 : 0,
                y: isPeeling ? -36 : 0
            )
            .opacity(isPeeling ? 0.15 : 1)
            .animation(.spring(response: 0.45, dampingFraction: 0.68), value: isPeeling)
    }

    private func peelSticker() {
        guard !isPeeling else { return }
        isPeeling = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            isPeeling = false
            onPeelComplete()
        }
    }
}

#Preview {
    ZStack(alignment: .topTrailing) {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.yellow.opacity(0.35))
            .frame(height: 180)
        PufferNotebookStickerButton(onPeelComplete: {})
            .padding(12)
    }
    .padding()
}
