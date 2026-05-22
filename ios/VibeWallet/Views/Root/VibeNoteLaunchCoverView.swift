import SwiftUI

/// 從桌面冷啟動：三孔活頁夾封面（「vibe note」）→ 翻開進入主畫面
struct VibeNoteLaunchCoverView: View {
    var onFinished: () -> Void

    @State private var titleRevealed = false
    @State private var openProgress: CGFloat = 0

    private enum BinderPalette {
        static let coverTop = Color(red: 168 / 255, green: 188 / 255, blue: 208 / 255)
        static let coverBottom = Color(red: 128 / 255, green: 158 / 255, blue: 188 / 255)
        static let spine = Color(red: 108 / 255, green: 138 / 255, blue: 168 / 255)
        static let holeShadow = Color(red: 72 / 255, green: 98 / 255, blue: 128 / 255)
        static let ringMetalLight = Color(red: 220 / 255, green: 228 / 255, blue: 236 / 255)
        static let ringMetalDark = Color(red: 140 / 255, green: 158 / 255, blue: 178 / 255)
        static let plateLight = Color(red: 200 / 255, green: 210 / 255, blue: 222 / 255)
        static let plateDark = Color(red: 150 / 255, green: 168 / 255, blue: 188 / 255)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                coverFace(size: geo.size)
                    .rotation3DEffect(
                        .degrees(Double(-92 * openProgress)),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .leading,
                        perspective: 0.55
                    )
                    .opacity(1 - Double(openProgress) * 0.95)

                if openProgress > 0.02 {
                    NotebookPaperBackground()
                        .opacity(Double(openProgress))
                        .allowsHitTesting(false)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { runLaunchSequence() }
    }

    private func coverFace(size: CGSize) -> some View {
        let binderWidth = max(56, size.width * 0.16)
        let ringCenters = binderRingYPositions(in: size)

        return ZStack(alignment: .leading) {
            LinearGradient(
                colors: [BinderPalette.coverTop, BinderPalette.coverBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 霧面塑膠高光
            LinearGradient(
                colors: [.white.opacity(0.22), .clear, .black.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 打孔（封面上的圓孔）
            ForEach(Array(ringCenters.enumerated()), id: \.offset) { _, y in
                Circle()
                    .fill(BinderPalette.holeShadow.opacity(0.55))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )
                    .position(x: binderWidth * 0.72, y: y)
            }

            // 活頁夾金屬軌 + 環
            BinderMechanismView(
                width: binderWidth,
                height: size.height,
                ringCenters: ringCenters,
                ringSpread: min(1, 1 - openProgress * 0.35)
            )

            // 左側書脊陰影
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [BinderPalette.spine, BinderPalette.spine.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 10)

            VStack(spacing: 10) {
                Text("vibe note")
                    .font(NotebookFont.title(44))
                    .foregroundStyle(AppTheme.ink)
                    .shadow(color: .white.opacity(0.45), radius: 0, x: 0, y: 1)

                Text("wallet")
                    .font(NotebookFont.label(15))
                    .foregroundStyle(AppTheme.pencil)
                    .tracking(2.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.leading, binderWidth * 0.35)
            .scaleEffect(titleRevealed ? 1 : 0.92)
            .opacity(titleRevealed ? 1 : 0)
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: .black.opacity(0.14), radius: 16, y: 8)
    }

    private func binderRingYPositions(in size: CGSize) -> [CGFloat] {
        let mid = size.height * 0.5
        let spread = min(size.height * 0.22, 200)
        return [mid - spread, mid, mid + spread]
    }

    private func runLaunchSequence() {
        withAnimation(.easeOut(duration: 0.55)) {
            titleRevealed = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_350_000_000)
            withAnimation(VibeMotion.launchCoverOpen) {
                openProgress = 1
            }
            try? await Task.sleep(nanoseconds: 520_000_000)
            onFinished()
        }
    }
}

// MARK: - 活頁夾金屬件

private struct BinderMechanismView: View {
    let width: CGFloat
    let height: CGFloat
    let ringCenters: [CGFloat]
    var ringSpread: CGFloat = 1

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 108 / 255, green: 138 / 255, blue: 168 / 255),
                            Color(red: 88 / 255, green: 118 / 255, blue: 148 / 255),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 4, y: 0)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 200 / 255, green: 210 / 255, blue: 222 / 255),
                            Color(red: 150 / 255, green: 168 / 255, blue: 188 / 255),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width * 0.55)
                .padding(.leading, width * 0.2)
                .shadow(color: .white.opacity(0.35), radius: 1, x: -1, y: 0)

            ForEach(Array(ringCenters.enumerated()), id: \.offset) { index, y in
                BinderRingView()
                    .frame(width: 34, height: 34)
                    .scaleEffect(x: ringSpread, y: 1, anchor: .leading)
                    .position(x: width * 0.78, y: y)
                    .shadow(color: .black.opacity(0.18), radius: 3, x: 2, y: 2)
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.7).delay(Double(index) * 0.04),
                        value: ringSpread
                    )
            }
        }
        .frame(width: width, height: height, alignment: .leading)
    }
}

private struct BinderRingView: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 220 / 255, green: 228 / 255, blue: 236 / 255),
                            Color(red: 140 / 255, green: 158 / 255, blue: 178 / 255),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 5
                )
            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 1.2)
                .padding(3)
            Circle()
                .fill(Color.black.opacity(0.08))
                .padding(10)
        }
    }
}

#Preview {
    VibeNoteLaunchCoverView(onFinished: {})
}
