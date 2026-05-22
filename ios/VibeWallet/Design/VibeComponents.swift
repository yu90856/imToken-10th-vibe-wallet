import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 頁面與捲動

extension View {
    /// 標準內容頁：筆記本底圖 + Deck 底部留白 +（iOS 26+）柔和捲動邊緣
    func vibeNotebookPage(colorScheme: ColorScheme, deckInset: Bool = true) -> some View {
        modifier(VibeNotebookPageModifier(colorScheme: colorScheme, deckInset: deckInset))
    }
}

private struct VibeNotebookPageModifier: ViewModifier {
    let colorScheme: ColorScheme
    let deckInset: Bool

    func body(content: Content) -> some View {
        content
            .background {
                AppTheme.pageBackground(for: colorScheme)
                    .ignoresSafeArea()
            }
            .modifier(VibeScrollEdgeModifier())
            .modifier(DeckInsetModifier(enabled: deckInset))
    }
}

private struct DeckInsetModifier: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled {
            content.walletDeckScrollInset()
        } else {
            content
        }
    }
}

private struct VibeScrollEdgeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

// MARK: - 區塊標題

struct VibeSectionHeader: View {
    let title: String
    var subtitle: String?
    var systemImage: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.xxSmall) {
            HStack(spacing: VibeSpacing.xSmall) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }
                Text(title)
                    .notebookHeadline(18)
                    .foregroundStyle(AppTheme.ink(for: colorScheme))
            }
            if let subtitle {
                Text(subtitle)
                    .notebookCaption(12)
                    .foregroundStyle(AppTheme.secondaryInk(for: colorScheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 按鈕

struct VibePrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .notebookHeadline(17)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isEnabled ? AnyShapeStyle(AppTheme.heroGradient) : AnyShapeStyle(Color.gray.opacity(0.35)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AppTheme.ink(for: colorScheme).opacity(0.15), lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct VibeSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .notebookHeadline(17)
            .padding(.vertical, 14)
            .foregroundStyle(AppTheme.primary)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        AppTheme.primary.opacity(configuration.isPressed ? 0.9 : 0.55),
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
                    )
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct VibeCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - 輸入框

struct VibeTextField: View {
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if axis == .vertical {
                TextField(placeholder, text: $text, axis: .vertical)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .font(NotebookFont.body(16))
        .padding(VibeSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.fieldFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppTheme.fieldStroke(for: colorScheme), lineWidth: 1)
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .modifier(VibeWritingToolsDisabledModifier())
    }
}

private struct VibeWritingToolsDisabledModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.writingToolsBehavior(.disabled)
        } else {
            content
        }
    }
}

// MARK: - 觸覺回饋

enum VibeHaptics {
    static func selection() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }

    static func success() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
}
