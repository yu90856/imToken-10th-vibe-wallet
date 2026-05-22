import SwiftUI

/// 首頁便條紙上、河豚貼紙正下方的 Bitrefill logo：撕起動畫與角度與 Puffer 一致
struct BitrefillNotebookStickerButton: View {
    var onPeelComplete: () -> Void

    @State private var isPeeling = false

    private let logoSize: CGFloat = 72
    private let restRotation: Double = -14
    private let peelRotation: Double = -38

    var body: some View {
        Button(action: peelSticker) {
            bitrefillLogoGraphic
        }
        .buttonStyle(.plain)
        .disabled(isPeeling)
        .accessibilityLabel("Bitrefill Agents")
        .accessibilityHint("點擊撕下貼紙並開啟 Bitrefill Agents")
    }

    private var bitrefillLogoGraphic: some View {
        Image("BitrefillNotebookSticker")
            .resizable()
            .scaledToFit()
            .frame(width: logoSize, height: logoSize)
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
            .fill(Color.mint.opacity(0.35))
            .frame(height: 160)
        BitrefillNotebookStickerButton(onPeelComplete: {})
            .padding(12)
    }
    .padding()
}
