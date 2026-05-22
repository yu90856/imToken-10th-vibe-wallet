import SwiftUI

struct RootView: View {
    @Bindable private var walletSession = WalletSession.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var tokenCoreWarmupFailed = false
    /// 每次冷啟動顯示筆記本封面；從背景回前景不會重播
    @State private var showLaunchCover = true

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
            .opacity(showLaunchCover ? 0 : 1)
            .scaleEffect(showLaunchCover ? 0.97 : 1)
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
            .animation(VibeMotion.modalSpring, value: walletSession.hasWallet)
            .animation(VibeMotion.launchCoverOpen, value: showLaunchCover)

            TokenCoreWebHost()
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)

            if showLaunchCover {
                VibeNoteLaunchCoverView {
                    withAnimation(VibeMotion.launchCoverOpen) {
                        showLaunchCover = false
                    }
                }
                .zIndex(1)
                .transition(.opacity)
            }
        }
        .task {
            walletSession.bootstrapIfNeeded()
            await warmupTokenCore()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                walletSession.refreshFromStorage()
                AppLifecycleCoordinator.onBecomeActive()
            case .background:
                AppLifecycleCoordinator.onEnterBackground()
            default:
                break
            }
        }
        .onAppear {
            AppLifecycleCoordinator.onBecomeActive()
        }
        .alert("Token Core 載入失敗", isPresented: $tokenCoreWarmupFailed) {
            Button("了解", role: .cancel) {}
        } message: {
            Text("簽名與新建錢包需要 Token Core。請在 Xcode 執行 Clean Build，並確認 App 內含 tcx_wasm.js 與 tcx_wasm_bg.wasm。")
        }
        .sheet(isPresented: googleFaucetPromptBinding) {
            if let address = walletSession.account?.address {
                GoogleSepoliaFaucetSheet(address: address) {
                    walletSession.clearGoogleSepoliaFaucetPrompt()
                }
            }
        }
    }

    private var googleFaucetPromptBinding: Binding<Bool> {
        Binding(
            get: {
                walletSession.shouldPromptGoogleSepoliaFaucet
                    && walletSession.hasWallet
                    && walletSession.account != nil
            },
            set: { presented in
                if !presented {
                    walletSession.clearGoogleSepoliaFaucetPrompt()
                }
            }
        )
    }

    private func warmupTokenCore() async {
        try? await Task.sleep(nanoseconds: 300_000_000)
        await walletSession.warmUpTokenCore()
        tokenCoreWarmupFailed = !walletSession.isTokenCoreReady && !walletSession.hasWallet
    }
}
