import Foundation
import Observation
import SwiftUI

@Observable
final class AppNavigationModel: @unchecked Sendable {
    var selectedTab: AppTab = .home
    var homePath = NavigationPath()
    var marketPath = NavigationPath()
    /// 從行情點代幣進入交換 Tab 時帶入
    var swapPreselectedToken: MarketToken?

    func goHome() {
        selectedTab = .home
        homePath = NavigationPath()
        marketPath = NavigationPath()
    }

    func openSwap(preselectedTo token: MarketToken? = nil) {
        swapPreselectedToken = token
        selectedTab = .swap
    }

    func openBitrefillShop(query: String) {
        selectedTab = .home
        marketPath = NavigationPath()
        homePath = NavigationPath()
        homePath.append(HomeRoute.bitrefillShop(initialQuery: query, previewProducts: []))
    }

    func openWalletTab() {
        selectedTab = .wallet
        homePath = NavigationPath()
        marketPath = NavigationPath()
    }

    func apply(deepLink: VibeDeepLink) {
        switch deepLink {
        case .bitrefillShop(let query):
            openBitrefillShop(query: query) // previewProducts 由深連結無法帶入
        case .wallet:
            openWalletTab()
        }
    }
}

// MARK: - Environment（避免 Preview / 子頁未注入時崩潰）

private enum AppNavigationModelKey: EnvironmentKey {
    static let defaultValue = AppNavigationModel()
}

extension EnvironmentValues {
    var appNavigation: AppNavigationModel {
        get { self[AppNavigationModelKey.self] }
        set { self[AppNavigationModelKey.self] = newValue }
    }
}
