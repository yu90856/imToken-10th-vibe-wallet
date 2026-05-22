import SwiftUI

/// 4pt 網格間距（對齊 swift-ios-skills / HIG）
enum VibeSpacing {
    static let xxSmall: CGFloat = 4
    static let xSmall: CGFloat = 8
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let mediumLarge: CGFloat = 20
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
    static let xxLarge: CGFloat = 40
}

extension EdgeInsets {
    static let vibePage = EdgeInsets(top: 8, leading: 20, bottom: 24, trailing: 20)
    static let vibeCard = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
}
