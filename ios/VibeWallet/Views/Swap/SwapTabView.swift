import SwiftUI

/// 底部 Tab「交換」根頁面（無預選代幣）
struct SwapTabView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            SwapView()
        }
    }
}

#Preview {
    SwapTabView()
}
