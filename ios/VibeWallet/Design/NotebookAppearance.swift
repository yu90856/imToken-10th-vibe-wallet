import SwiftUI
import UIKit

enum NotebookAppearance {
    @MainActor
    static func install() {
        let navTitle = UIFont(name: NotebookFont.titleName, size: 34)
            ?? UIFont.systemFont(ofSize: 34, weight: .bold)
        let navInline = UIFont(name: NotebookFont.titleName, size: 20)
            ?? UIFont.systemFont(ofSize: 20, weight: .semibold)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        let titleColor = UIColor(AppTheme.ink)
        appearance.largeTitleTextAttributes = [
            .font: navTitle,
            .foregroundColor: titleColor,
        ]
        appearance.titleTextAttributes = [
            .font: navInline,
            .foregroundColor: titleColor,
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(AppTheme.primary)
    }
}
