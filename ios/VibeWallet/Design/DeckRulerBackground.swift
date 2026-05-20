import SwiftUI

/// 整條 Deck 橫幅：平放的手繪直尺底圖（刻度橫向排列）
struct DeckRulerBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                rulerBody
                centerGroove(in: geo.size)
                horizontalTicks(in: geo.size)
                edgeHighlights(in: geo.size)
            }
        }
    }

    private var rulerBody: some View {
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(red: 58 / 255, green: 72 / 255, blue: 88 / 255),
                        Color(red: 48 / 255, green: 58 / 255, blue: 72 / 255),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 248 / 255, green: 252 / 255, blue: 255 / 255),
                        Color(red: 218 / 255, green: 235 / 255, blue: 248 / 255),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    private func centerGroove(in size: CGSize) -> some View {
        Path { path in
            let y = size.height * 0.52
            path.move(to: CGPoint(x: 10, y: y))
            path.addLine(to: CGPoint(x: size.width - 10, y: y))
        }
        .stroke(
            AppTheme.pencil.opacity(colorScheme == .dark ? 0.25 : 0.18),
            style: StrokeStyle(lineWidth: 0.8, dash: [4, 3])
        )
    }

    /// 尺規刻度：沿上緣向下（平放直尺俯視）
    private func horizontalTicks(in size: CGSize) -> some View {
        let inset: CGFloat = 10
        let usable = size.width - inset * 2
        let divisions = max(24, Int(usable / 14))
        let step = usable / CGFloat(divisions)

        return ZStack(alignment: .topLeading) {
            Path { path in
                for i in 0...divisions {
                    let x = inset + CGFloat(i) * step
                    let isMajor = i % 5 == 0
                    let isMid = i % 5 == 2
                    let tickH: CGFloat = isMajor ? 16 : (isMid ? 11 : 7)
                    let top: CGFloat = 5
                    path.move(to: CGPoint(x: x, y: top))
                    path.addLine(to: CGPoint(x: x, y: top + tickH))
                }
            }
            .stroke(tickColor, lineWidth: 1.1)

            Text("cm")
                .font(NotebookFont.label(9))
                .foregroundStyle(tickColor.opacity(0.75))
                .padding(.leading, inset + 2)
                .padding(.top, 22)
        }
    }

    private var tickColor: Color {
        colorScheme == .dark
            ? AppTheme.inkOnDark.opacity(0.55)
            : AppTheme.pencil.opacity(0.55)
    }

    private func edgeHighlights(in size: CGSize) -> some View {
        ZStack {
            // 上緣亮邊（尺身厚度）
            Path { path in
                path.move(to: CGPoint(x: 8, y: 1))
                path.addLine(to: CGPoint(x: size.width - 8, y: 1))
            }
            .stroke(
                Color.white.opacity(colorScheme == .dark ? 0.12 : 0.65),
                lineWidth: 1
            )

            // 下緣暗邊
            Path { path in
                let y = size.height - 1.5
                path.move(to: CGPoint(x: 8, y: y))
                path.addLine(to: CGPoint(x: size.width - 8, y: y))
            }
            .stroke(
                AppTheme.ink.opacity(colorScheme == .dark ? 0.35 : 0.12),
                lineWidth: 1
            )
        }
    }
}

#Preview {
    DeckRulerBackground()
        .frame(height: 68)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding()
}
