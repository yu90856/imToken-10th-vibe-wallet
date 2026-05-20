import SwiftUI

/// 橫線筆記紙背景 + 左側紅色邊線
struct NotebookPaperBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .leading) {
            paperBase
            ruledLines
            marginLine
        }
        .ignoresSafeArea()
    }

    private var paperBase: some View {
        Group {
            if colorScheme == .dark {
                Color(red: 38 / 255, green: 34 / 255, blue: 28 / 255)
            } else {
                Color(red: 252 / 255, green: 248 / 255, blue: 236 / 255)
            }
        }
    }

    private var ruledLines: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 28
            let count = Int(geo.size.height / spacing) + 2
            Path { path in
                for i in 0..<count {
                    let y = CGFloat(i) * spacing + 24
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
            }
            .stroke(
                colorScheme == .dark
                    ? Color(red: 70 / 255, green: 90 / 255, blue: 110 / 255).opacity(0.35)
                    : Color(red: 170 / 255, green: 198 / 255, blue: 230 / 255).opacity(0.55),
                style: StrokeStyle(lineWidth: 0.8, dash: [2, 3])
            )
        }
    }

    private var marginLine: some View {
        Rectangle()
            .fill(
                colorScheme == .dark
                    ? Color(red: 180 / 255, green: 90 / 255, blue: 90 / 255).opacity(0.5)
                    : Color(red: 230 / 255, green: 120 / 255, blue: 120 / 255).opacity(0.65)
            )
            .frame(width: 2)
            .padding(.leading, 22)
    }
}
