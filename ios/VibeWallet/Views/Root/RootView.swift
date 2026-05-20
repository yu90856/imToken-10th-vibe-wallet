import SwiftUI

struct RootView: View {
    @Bindable private var walletSession = WalletSession.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var tokenCoreWarmupFailed = false

    var body: some View {
        ZStack {
            Group {
                if walletSession.hasWallet {
                    MainTabView()
                        .environment(walletSession)
                } else {
                    WalletOnboardingView()
                        .environment(walletSession)
                }
            }

            TokenCoreWebHost()
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
        }
        .task {
            await warmupTokenCore()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                walletSession.refreshFromStorage()
            }
        }
        .alert("Token Core 載入失敗", isPresented: $tokenCoreWarmupFailed) {
            Button("了解", role: .cancel) {}
        } message: {
            Text("簽名與新建錢包需要 Token Core。請在 Xcode 執行 Clean Build，並確認 App 內含 tcx_wasm.js 與 tcx_wasm_bg.wasm。")
        }
    }

    private func warmupTokenCore() async {
        try? await Task.sleep(nanoseconds: 300_000_000)
        await walletSession.warmUpTokenCore()
        tokenCoreWarmupFailed = !walletSession.isTokenCoreReady && !walletSession.hasWallet
    }
}
