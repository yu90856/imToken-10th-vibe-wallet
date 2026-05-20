import SwiftUI

@main
struct VibeWalletApp: App {
    init() {
        NotebookAppearance.install()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .font(NotebookFont.body())
                .tint(AppTheme.primary)
                // 筆記本設計以淺色紙為準；跟隨系統深色會導致字色與模擬器不一致
                .preferredColorScheme(.light)
        }
    }
}
