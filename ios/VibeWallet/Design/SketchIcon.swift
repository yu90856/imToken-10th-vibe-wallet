import SwiftUI

/// 手繪／鉛筆風格圖示（Path 描邊，非 SF Symbol）
struct SketchIcon: View {
    enum Kind: String {
        case home
        case market
        case swap
        case explore
        case wallet
        case refresh
        case gear
        case lock
        case search
        case star
        case chart
        case shield
        case drop
        case link
        case copy
        case eye
        case chevronLeft
        case ruler
    }

    let kind: Kind
    var size: CGFloat = 24
    var color: Color = AppTheme.ink

    var body: some View {
        Group {
            if kind == .gear {
                SketchGearIcon(size: size, color: color)
            } else {
                Canvas { context, canvasSize in
                    let rect = CGRect(origin: .zero, size: canvasSize)
                    let path = sketchPath(for: kind, in: rect)
                    context.stroke(
                        path,
                        with: .color(color),
                        style: StrokeStyle(
                            lineWidth: max(1.6, size * 0.07),
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }
                .frame(width: size, height: size)
            }
        }
        .accessibilityLabel(kind.rawValue)
    }

    private func sketchPath(for kind: Kind, in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let pad = min(w, h) * 0.12

        var path = Path()
        switch kind {
        case .home:
            let roof = CGPoint(x: w * 0.5, y: pad)
            path.move(to: roof)
            path.addLine(to: CGPoint(x: w - pad, y: h * 0.42))
            path.addLine(to: CGPoint(x: w - pad, y: h - pad))
            path.addLine(to: CGPoint(x: pad, y: h - pad))
            path.addLine(to: CGPoint(x: pad, y: h * 0.42))
            path.closeSubpath()
            path.move(to: CGPoint(x: w * 0.38, y: h - pad))
            path.addLine(to: CGPoint(x: w * 0.38, y: h * 0.58))
            path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.58))
            path.addLine(to: CGPoint(x: w * 0.62, y: h - pad))

        case .market:
            path.move(to: CGPoint(x: pad, y: h * 0.72))
            path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.45))
            path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.58))
            path.addLine(to: CGPoint(x: w - pad, y: pad + 2))

        case .swap:
            path.move(to: CGPoint(x: pad + 2, y: h * 0.35))
            path.addLine(to: CGPoint(x: w - pad, y: h * 0.35))
            path.move(to: CGPoint(x: w * 0.72, y: h * 0.22))
            path.addLine(to: CGPoint(x: w - pad, y: h * 0.35))
            path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.48))
            path.move(to: CGPoint(x: w - pad, y: h * 0.65))
            path.addLine(to: CGPoint(x: pad, y: h * 0.65))
            path.move(to: CGPoint(x: w * 0.28, y: h * 0.52))
            path.addLine(to: CGPoint(x: pad, y: h * 0.65))
            path.addLine(to: CGPoint(x: w * 0.28, y: h * 0.78))

        case .explore:
            let c = CGPoint(x: w * 0.5, y: h * 0.5)
            path.addEllipse(in: CGRect(x: pad, y: pad + 1, width: w - pad * 2, height: h - pad * 2))
            path.move(to: CGPoint(x: c.x, y: pad + 2))
            path.addLine(to: CGPoint(x: c.x, y: h - pad))
            path.move(to: CGPoint(x: pad + 2, y: c.y))
            path.addLine(to: CGPoint(x: w - pad, y: c.y))

        case .wallet:
            let r = CGRect(x: pad, y: h * 0.28, width: w - pad * 2, height: h * 0.52)
            path.addRoundedRect(in: r, cornerSize: CGSize(width: 5, height: 5))
            path.move(to: CGPoint(x: pad + 4, y: h * 0.42))
            path.addLine(to: CGPoint(x: w - pad - 4, y: h * 0.42))

        case .refresh:
            path.addArc(
                center: CGPoint(x: w * 0.5, y: h * 0.5),
                radius: min(w, h) * 0.34,
                startAngle: .degrees(30),
                endAngle: .degrees(300),
                clockwise: false
            )
            path.move(to: CGPoint(x: w * 0.68, y: h * 0.28))
            path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.18))
            path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.2))

        case .gear:
            break

        case .lock:
            let body = CGRect(x: w * 0.28, y: h * 0.44, width: w * 0.44, height: h * 0.44)
            path.addRoundedRect(in: body, cornerSize: CGSize(width: 4, height: 4))
            path.move(to: CGPoint(x: w * 0.38, y: h * 0.44))
            path.addLine(to: CGPoint(x: w * 0.38, y: h * 0.32))
            path.addQuadCurve(
                to: CGPoint(x: w * 0.62, y: h * 0.32),
                control: CGPoint(x: w * 0.5, y: h * 0.18)
            )
            path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.44))
            path.move(to: CGPoint(x: w * 0.46, y: h * 0.58))
            path.addLine(to: CGPoint(x: w * 0.54, y: h * 0.58))

        case .search:
            path.addEllipse(in: CGRect(x: pad, y: pad, width: w * 0.55, height: h * 0.55))
            path.move(to: CGPoint(x: w * 0.58, y: h * 0.58))
            path.addLine(to: CGPoint(x: w - pad, y: h - pad))

        case .star:
            let center = CGPoint(x: w * 0.5, y: h * 0.52)
            let outer = min(w, h) * 0.38
            let inner = outer * 0.45
            for i in 0..<10 {
                let angle = Double(i) * .pi / 5 - .pi / 2
                let r = i.isMultiple(of: 2) ? outer : inner
                let pt = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * r,
                    y: center.y + CGFloat(sin(angle)) * r
                )
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            path.closeSubpath()

        case .chart:
            path.move(to: CGPoint(x: pad, y: h - pad))
            path.addLine(to: CGPoint(x: pad, y: pad))
            path.addLine(to: CGPoint(x: w - pad, y: pad))
            path.move(to: CGPoint(x: w * 0.32, y: h * 0.62))
            path.addLine(to: CGPoint(x: w * 0.32, y: h * 0.38))
            path.move(to: CGPoint(x: w * 0.55, y: h * 0.62))
            path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.48))
            path.move(to: CGPoint(x: w * 0.78, y: h * 0.62))
            path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.3))

        case .shield:
            path.move(to: CGPoint(x: w * 0.5, y: pad))
            path.addLine(to: CGPoint(x: w - pad, y: h * 0.32))
            path.addQuadCurve(
                to: CGPoint(x: w * 0.5, y: h - pad),
                control: CGPoint(x: w - pad, y: h * 0.72)
            )
            path.addQuadCurve(
                to: CGPoint(x: pad, y: h * 0.32),
                control: CGPoint(x: pad, y: h * 0.72)
            )
            path.closeSubpath()

        case .drop:
            path.move(to: CGPoint(x: w * 0.5, y: pad))
            path.addQuadCurve(
                to: CGPoint(x: w * 0.5, y: h - pad),
                control: CGPoint(x: w - pad, y: h * 0.45)
            )
            path.addQuadCurve(
                to: CGPoint(x: w * 0.5, y: pad),
                control: CGPoint(x: pad, y: h * 0.45)
            )

        case .link:
            path.addEllipse(in: CGRect(x: pad, y: h * 0.35, width: w * 0.42, height: h * 0.35))
            path.addEllipse(in: CGRect(x: w * 0.38, y: pad, width: w * 0.42, height: h * 0.35))

        case .copy:
            let r1 = CGRect(x: w * 0.28, y: pad, width: w * 0.5, height: h * 0.55)
            let r2 = CGRect(x: pad, y: h * 0.22, width: w * 0.5, height: h * 0.55)
            path.addRoundedRect(in: r1, cornerSize: CGSize(width: 3, height: 3))
            path.addRoundedRect(in: r2, cornerSize: CGSize(width: 3, height: 3))

        case .eye:
            path.addEllipse(in: CGRect(x: pad, y: h * 0.32, width: w - pad * 2, height: h * 0.38))
            path.addEllipse(in: CGRect(x: w * 0.36, y: h * 0.4, width: w * 0.28, height: h * 0.22))

        case .chevronLeft:
            path.move(to: CGPoint(x: w * 0.62, y: pad))
            path.addLine(to: CGPoint(x: pad, y: h * 0.5))
            path.addLine(to: CGPoint(x: w * 0.62, y: h - pad))

        case .ruler:
            let body = CGRect(x: w * 0.22, y: pad, width: w * 0.56, height: h - pad * 2)
            path.addRoundedRect(in: body, cornerSize: CGSize(width: 2, height: 2))
            let tickCount = 7
            for i in 0...tickCount {
                let t = CGFloat(i) / CGFloat(tickCount)
                let y = body.minY + body.height * t
                let tickLen: CGFloat = i % 2 == 0 ? w * 0.22 : w * 0.14
                path.move(to: CGPoint(x: body.maxX, y: y))
                path.addLine(to: CGPoint(x: body.maxX - tickLen, y: y))
            }
            path.move(to: CGPoint(x: body.minX + body.width * 0.35, y: body.minY + body.height * 0.2))
            path.addLine(to: CGPoint(x: body.minX + body.width * 0.35, y: body.maxY - body.height * 0.15))
        }
        return path
    }
}

// MARK: - 手繪鉛筆風齒輪（附圖：描邊 + 斜線陰影）

private struct SketchGearIcon: View {
    let size: CGFloat
    let color: Color

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
            let outline = gearOutline(in: rect)
            let stroke = StrokeStyle(
                lineWidth: max(1.5, size * 0.065),
                lineCap: .round,
                lineJoin: .round
            )

            for hatch in gearHatchLines(in: rect) {
                context.stroke(
                    hatch,
                    with: .color(color.opacity(0.32)),
                    style: StrokeStyle(lineWidth: max(0.7, size * 0.028), lineCap: .round)
                )
            }

            context.stroke(outline, with: .color(color), style: stroke)

            let hubR = min(rect.width, rect.height) * 0.11
            let hub = CGRect(
                x: rect.midX - hubR,
                y: rect.midY - hubR,
                width: hubR * 2,
                height: hubR * 2
            )
            context.stroke(Path(ellipseIn: hub), with: .color(color), style: stroke)

            var spokes = Path()
            let spokeLen = hubR * 1.35
            spokes.move(to: CGPoint(x: rect.midX - spokeLen, y: rect.midY))
            spokes.addLine(to: CGPoint(x: rect.midX + spokeLen, y: rect.midY))
            spokes.move(to: CGPoint(x: rect.midX, y: rect.midY - spokeLen))
            spokes.addLine(to: CGPoint(x: rect.midX, y: rect.midY + spokeLen))
            context.stroke(spokes, with: .color(color.opacity(0.85)), style: stroke)
        }
        .frame(width: size, height: size)
    }

    private func gearOutline(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let outerR = min(rect.width, rect.height) * 0.42
        let innerR = outerR * 0.72
        let teeth = 8
        var path = Path()

        for i in 0..<(teeth * 2) {
            let angle = (Double(i) / Double(teeth * 2)) * 2 * .pi - .pi / 2
            let r = i.isMultiple(of: 2) ? outerR : innerR
            let pt = CGPoint(
                x: c.x + CGFloat(cos(angle)) * r,
                y: c.y + CGFloat(sin(angle)) * r
            )
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    private func gearHatchLines(in rect: CGRect) -> [Path] {
        let pad = min(rect.width, rect.height) * 0.2
        let inner = rect.insetBy(dx: pad, dy: pad)
        let spacing = max(2.5, size * 0.11)
        var lines: [Path] = []
        var y = inner.minY
        while y < inner.maxY {
            var p = Path()
            p.move(to: CGPoint(x: inner.minX, y: y))
            p.addLine(to: CGPoint(x: inner.maxX, y: y + inner.width * 0.22))
            lines.append(p)
            y += spacing
        }
        return lines
    }
}
