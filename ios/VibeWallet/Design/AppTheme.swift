import SwiftUI

enum AppTheme {
    // 筆記本／鉛筆色票
    static let ink = Color(red: 45 / 255, green: 42 / 255, blue: 38 / 255)
    /// 深色模式下仍可讀的文字色（若未強制淺色時使用）
    static let inkOnDark = Color(red: 245 / 255, green: 240 / 255, blue: 230 / 255)
    static let pencil = Color(red: 75 / 255, green: 110 / 255, blue: 145 / 255)

    static func ink(for scheme: ColorScheme) -> Color {
        scheme == .dark ? inkOnDark : ink
    }

    static func secondaryInk(for scheme: ColorScheme) -> Color {
        ink(for: scheme).opacity(0.65)
    }
    static let primary = pencil
    /// 與 Web token-ui `--primary` 對齊的互動藍（CTA 漸層點綴）
    static let brandBlue = Color(red: 0 / 255, green: 127 / 255, blue: 255 / 255)
    static let secondary = Color(red: 95 / 255, green: 130 / 255, blue: 160 / 255)
    static let deepNavy = ink

    static let positive = Color(red: 56 / 255, green: 130 / 255, blue: 90 / 255)
    static let negative = Color(red: 190 / 255, green: 75 / 255, blue: 70 / 255)
    static let warning = Color(red: 210 / 255, green: 150 / 255, blue: 60 / 255)

    static let paperLight = Color(red: 252 / 255, green: 248 / 255, blue: 236 / 255)
    static let paperDark = Color(red: 38 / 255, green: 34 / 255, blue: 28 / 255)

    /// 便利貼主色
    static let stickyYellow = Color(red: 255 / 255, green: 244 / 255, blue: 170 / 255)
    static let stickyYellowShadow = Color(red: 235 / 255, green: 210 / 255, blue: 120 / 255)
    static let stickyPink = Color(red: 255 / 255, green: 228 / 255, blue: 210 / 255)
    static let stickyMint = Color(red: 215 / 255, green: 245 / 255, blue: 210 / 255)

    @ViewBuilder
    static func pageBackground(for scheme: ColorScheme) -> some View {
        NotebookPaperBackground()
    }

    static func stickyNoteFill(for scheme: ColorScheme, variant: StickyNoteVariant = .yellow) -> Color {
        if scheme == .dark {
            switch variant {
            case .yellow: return Color(red: 92 / 255, green: 82 / 255, blue: 48 / 255)
            case .pink: return Color(red: 100 / 255, green: 72 / 255, blue: 68 / 255)
            case .mint: return Color(red: 68 / 255, green: 92 / 255, blue: 72 / 255)
            }
        }
        switch variant {
        case .yellow: return stickyYellow
        case .pink: return stickyPink
        case .mint: return stickyMint
        }
    }

    static func stickyNoteShadow(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.black.opacity(0.35)
            : stickyYellowShadow.opacity(0.55)
    }

    static func cardFill(for scheme: ColorScheme) -> Color {
        stickyNoteFill(for: scheme)
    }

    static func cardStroke(for scheme: ColorScheme) -> Color {
        scheme == .dark ? pencil.opacity(0.35) : ink.opacity(0.15)
    }

    static func primaryGlow(for scheme: ColorScheme) -> Color {
        pencil.opacity(scheme == .dark ? 0.25 : 0.15)
    }

    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 120 / 255, green: 155 / 255, blue: 190 / 255),
            Color(red: 75 / 255, green: 110 / 255, blue: 145 / 255),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let ctaGradient = LinearGradient(
        colors: [brandBlue.opacity(0.92), pencil],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func fieldFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.72)
    }

    static func fieldStroke(for scheme: ColorScheme) -> Color {
        scheme == .dark ? pencil.opacity(0.35) : ink.opacity(0.12)
    }

    static let meshAccent = LinearGradient(
        colors: [pencil.opacity(0.85), secondary.opacity(0.65)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

enum StickyNoteVariant {
    case yellow
    case pink
    case mint
}

/// 獨立內容區塊：便利貼質感（非 Deck／全頁底圖）
struct StickyNoteCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = 10
    var variant: StickyNoteVariant = .yellow
    var tiltDegrees: Double = 0

    func body(content: Content) -> some View {
        content
            .background(
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(AppTheme.stickyNoteShadow(for: colorScheme))
                        .offset(x: 4, y: 5)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(AppTheme.stickyNoteFill(for: colorScheme, variant: variant))

                    // 上方膠帶
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.45))
                        .frame(height: 10)
                        .padding(.horizontal, 36)
                        .padding(.top, 6)
                        .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.cardStroke(for: colorScheme), lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: AppTheme.ink.opacity(0.12), radius: 5, x: 2, y: 4)
            .rotationEffect(.degrees(tiltDegrees))
    }
}

typealias GlassCardModifier = StickyNoteCardModifier

extension View {
    func glassCard(cornerRadius: CGFloat = 10, variant: StickyNoteVariant = .yellow, tilt: Double = 0) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, variant: variant, tiltDegrees: tilt))
    }
}
