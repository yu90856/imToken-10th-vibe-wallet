import SwiftUI

/// 筆記本／鉛筆手寫風格字型（系統內建，無需額外 bundle）
enum NotebookFont {
    static let bodyName = "Chalkboard SE"
    static let titleName = "Bradley Hand"
    static let accentName = "Marker Felt"

    static func body(_ size: CGFloat = 17) -> Font {
        .custom(bodyName, size: size)
    }

    static func title(_ size: CGFloat = 28) -> Font {
        .custom(titleName, size: size)
    }

    static func headline(_ size: CGFloat = 20) -> Font {
        .custom(titleName, size: size)
    }

    static func caption(_ size: CGFloat = 13) -> Font {
        .custom(bodyName, size: size)
    }

    static func label(_ size: CGFloat = 11) -> Font {
        .custom(accentName, size: size)
    }

    static func largeAmount(_ size: CGFloat = 38) -> Font {
        .custom(titleName, size: size)
    }
}

extension View {
    func notebookBody(_ size: CGFloat = 17) -> some View {
        font(NotebookFont.body(size))
    }

    func notebookTitle(_ size: CGFloat = 28) -> some View {
        font(NotebookFont.title(size))
    }

    func notebookHeadline(_ size: CGFloat = 20) -> some View {
        font(NotebookFont.headline(size))
    }

    func notebookCaption(_ size: CGFloat = 13) -> some View {
        font(NotebookFont.caption(size))
    }
}
