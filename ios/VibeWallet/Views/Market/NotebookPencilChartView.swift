import SwiftUI

/// 鉛筆手繪線圖（分段短描 + 多層石墨灰疊線）
struct NotebookPencilChartView: View {
    let pack: MarketChartSeriesPack
    let timeframe: MarketChartTimeframe
    @Environment(\.colorScheme) private var colorScheme

    private let width: CGFloat = 360
    private let height: CGFloat = 220
    private let padX: CGFloat = 36
    private let padY: CGFloat = 22

    private struct PencilLayer {
        let dx: CGFloat
        let dy: CGFloat
        let width: CGFloat
        let opacity: Double
    }

    private static let pencilLayers: [PencilLayer] = [
        .init(dx: 0, dy: 0, width: 2.6, opacity: 0.62),
        .init(dx: 0.55, dy: -0.35, width: 1.9, opacity: 0.38),
        .init(dx: -0.45, dy: 0.3, width: 1.7, opacity: 0.32),
        .init(dx: 0.25, dy: 0.2, width: 1.2, opacity: 0.22),
        .init(dx: -0.2, dy: -0.15, width: 0.9, opacity: 0.16),
    ]

    var body: some View {
        let points = wobblePoints(
            values: pack.prices,
            seed: timeframe.rawValue.count * 3
        )
        let seed = timeframe.rawValue.count * 5 + pack.prices.count
        let pencilPath = pointsToPencilPath(points: points, seed: seed)
        let smudgePath = smudgeArea(points: points, pencilPath: pencilPath)
        let graphite = AppTheme.ink(for: colorScheme).opacity(0.55)
        let graphiteLight = AppTheme.ink(for: colorScheme).opacity(0.28)
        let paperBg = AppTheme.stickyNoteFill(for: colorScheme).opacity(colorScheme == .dark ? 0.35 : 0.85)
        let grid = AppTheme.ink(for: colorScheme).opacity(0.12)
        let faint = AppTheme.secondaryInk(for: colorScheme)
        let yTicks = [pack.high, (pack.high + pack.low) / 2, pack.low]

        Canvas { context, size in
            let scaleX = size.width / (width + 28)
            let scaleY = size.height / (height + 28)
            context.scaleBy(x: scaleX, y: scaleY)

            let sheet = CGRect(x: 8, y: 6, width: width - 16, height: height + 10)
            context.fill(Path(roundedRect: sheet, cornerRadius: 10), with: .color(paperBg))
            context.stroke(
                Path(roundedRect: sheet, cornerRadius: 10),
                with: .color(AppTheme.cardStroke(for: colorScheme)),
                lineWidth: 1.2
            )

            for (index, ratio) in [0.22, 0.42, 0.62, 0.82].enumerated() {
                let y = padY + CGFloat(ratio) * (height - padY * 2) + (index.isMultiple(of: 2) ? 0.6 : -0.4)
                var line = Path()
                line.move(to: CGPoint(x: padX - 8, y: y))
                line.addLine(to: CGPoint(x: width - padX + 8, y: y))
                context.stroke(line, with: .color(grid), style: StrokeStyle(lineWidth: 0.9, dash: [3, 5]))
            }

            if let smudge = smudgePath {
                context.fill(smudge, with: .color(graphiteLight.opacity(0.08)))
            }

            for layer in Self.pencilLayers {
                var layerPath = pencilPath
                layerPath = layerPath.applying(CGAffineTransform(translationX: layer.dx, y: layer.dy))
                context.stroke(
                    layerPath,
                    with: .color(graphite.opacity(layer.opacity)),
                    style: StrokeStyle(lineWidth: layer.width, lineCap: .round, lineJoin: .round)
                )
            }

            for (index, point) in points.enumerated() {
                let isLast = index == points.count - 1
                let radius: CGFloat = isLast ? 3.8 : 2.2
                let ring = Path(ellipseIn: CGRect(
                    x: point.x + 0.15 - radius,
                    y: point.y - 0.1 - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                context.stroke(
                    ring,
                    with: .color(graphite.opacity(isLast ? 0.85 : 0.45)),
                    lineWidth: isLast ? 1.8 : 1.1
                )
                if isLast {
                    let dot = Path(ellipseIn: CGRect(x: point.x - 1.2, y: point.y - 1.2, width: 2.4, height: 2.4))
                    context.fill(dot, with: .color(graphite.opacity(0.7)))
                }
            }
        }
        .frame(maxWidth: 420)
        .frame(height: 248)
        .overlay(alignment: .leading) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(yTicks.enumerated()), id: \.offset) { index, value in
                    let yRatio = CGFloat(index) / CGFloat(max(yTicks.count - 1, 1))
                    Text(formatTickUSD(value))
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(faint)
                        .offset(y: padY + yRatio * (height - padY * 2) - 6)
                }
            }
            .padding(.leading, 4)
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 0) {
                ForEach(Array(pack.labels.enumerated()), id: \.offset) { index, label in
                    if index % 2 == 0 || pack.labels.count <= 6,
                       index < points.count {
                        Text(label)
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(faint)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, padX)
            .padding(.bottom, 2)
        }
        .accessibilityLabel("價格線圖 \(timeframe.label)")
    }

    private func formatTickUSD(_ value: Double) -> String {
        if value < 0.01 { return String(format: "$%.5f", value) }
        if value < 1 { return String(format: "$%.4f", value) }
        return String(format: "$%.2f", value)
    }

    private func wobblePoints(values: [Double], seed: Int) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 1
        let span = max(maxV - minV, 0.000_000_1)
        let innerW = width - padX * 2
        let innerH = height - padY * 2
        return values.enumerated().map { index, value in
            let t = values.count <= 1 ? 0.5 : Double(index) / Double(values.count - 1)
            let jitterX = sin(Double(index + seed) * 2.17) * 1.4 + cos(Double(index + seed) * 1.31) * 0.9
            let jitterY = sin(Double(index + seed) * 1.9) * 1.1 + cos(Double(index + seed) * 1.5) * 0.8
            let x = padX + CGFloat(t) * innerW + CGFloat(jitterX * 0.35)
            let y = padY + (1 - CGFloat((value - minV) / span)) * innerH + CGFloat(jitterY * 0.25)
            return CGPoint(x: x, y: y)
        }
    }

    private func pointsToPencilPath(points: [CGPoint], seed: Int) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        let rest = Array(points.dropFirst())
        for (index, current) in rest.enumerated() {
            let previous = index == 0 ? first : rest[index - 1]
            for step in 1...4 {
                let t = CGFloat(step) / 4
                let wobbleX = CGFloat(sin(Double(seed + index) * 1.73 + Double(step) * 0.91)) * 0.75
                let wobbleY = CGFloat(cos(Double(seed + index) * 1.41 + Double(step) * 1.07)) * 0.65
                let x = previous.x + (current.x - previous.x) * t + wobbleX
                let y = previous.y + (current.y - previous.y) * t + wobbleY
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }

    private func smudgeArea(points: [CGPoint], pencilPath: Path) -> Path? {
        guard let first = points.first, let last = points.last else { return nil }
        var path = pencilPath
        let baseY = height - padY + 4
        path.addLine(to: CGPoint(x: last.x, y: baseY))
        path.addLine(to: CGPoint(x: first.x, y: baseY))
        path.closeSubpath()
        return path
    }
}
