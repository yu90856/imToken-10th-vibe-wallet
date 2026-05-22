import SwiftUI

/// 全 App 共用轉場與動畫曲線
enum VibeMotion {
    static let tabSpring = Animation.spring(response: 0.42, dampingFraction: 0.86)
    static let navigationSpring = Animation.spring(response: 0.38, dampingFraction: 0.9)
    static let modalSpring = Animation.spring(response: 0.45, dampingFraction: 0.88)
    static let quickEase = Animation.easeInOut(duration: 0.22)
    /// 啟動封面翻開
    static let launchCoverOpen = Animation.spring(response: 0.52, dampingFraction: 0.84)

    private static let tabOrder: [AppTab] = [.home, .market, .swap, .explore, .wallet]

    static func tabTransition(from previous: AppTab, to next: AppTab) -> AnyTransition {
        let insertionEdge = slideEdge(from: previous, to: next)
        let removalEdge: Edge = insertionEdge == .trailing ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }

    private static func slideEdge(from: AppTab, to: AppTab) -> Edge {
        guard let fromIndex = tabOrder.firstIndex(of: from),
              let toIndex = tabOrder.firstIndex(of: to) else {
            return .trailing
        }
        return toIndex >= fromIndex ? .trailing : .leading
    }
}

// MARK: - 分頁切換

private struct VibeTabAnimatedContentModifier: ViewModifier {
    let selectedTab: AppTab
    let transition: AnyTransition

    func body(content: Content) -> some View {
        content
            .id(selectedTab)
            .transition(transition)
    }
}

extension View {
    /// 底部 Deck 切換主分頁時的滑入轉場
    func vibeTabAnimatedContent(selectedTab: AppTab, previousTab: AppTab) -> some View {
        modifier(
            VibeTabAnimatedContentModifier(
                selectedTab: selectedTab,
                transition: VibeMotion.tabTransition(from: previousTab, to: selectedTab)
            )
        )
    }

    /// 子頁面 push：沿用 NavigationStack 預設轉場，並由 `vibeNavigationPathAnimation` 調整節奏
    func vibeNavigationPushStyle() -> some View {
        self
    }

    /// Sheet / 全螢幕彈層樣式
    func vibeModalPresentationStyle() -> some View {
        presentationCornerRadius(22)
            .presentationDragIndicator(.visible)
    }

    /// 套在 sheet / fullScreenCover 內容根視圖
    func vibePresentedScreen() -> some View {
        vibeModalPresentationStyle()
    }

    /// 根畫面切換（例如 onboarding ↔ 主畫面）
    func vibeRootScreenTransition(isActive: Bool) -> some View {
        opacity(isActive ? 1 : 0)
            .scaleEffect(isActive ? 1 : 0.97)
            .animation(VibeMotion.modalSpring, value: isActive)
    }

    /// 綁定 NavigationPath 深度變化時的彈簧
    func vibeNavigationPathAnimation(_ path: NavigationPath) -> some View {
        animation(VibeMotion.navigationSpring, value: path.count)
    }
}
