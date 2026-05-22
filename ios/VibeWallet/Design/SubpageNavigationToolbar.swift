import SwiftUI

/// 子頁面不再顯示頂部「返回／首頁」按鈕，改由底部 Deck 導覽
struct SubpageNavigationToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content.vibeNavigationPushStyle()
    }
}

extension View {
    func subpageNavigation(backTitle: String = "返回") -> some View {
        modifier(SubpageNavigationToolbar())
    }
}
