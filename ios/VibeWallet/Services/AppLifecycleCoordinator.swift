import SwiftUI
import UIKit

/// 啟動監控、Widget 同步、通知權限
@MainActor
enum AppLifecycleCoordinator {
    static func onAppLaunch() {
        VibeNotificationService.configure()
        HomeWeatherService.shared.beginLocationAndWeather()
        Task {
            _ = await VibeNotificationService.requestAuthorizationIfNeeded()
            await WidgetSyncService.refreshFromApp()
        }
    }

    static func onBecomeActive() {
        HomeWeatherService.shared.refreshIfNeeded()
        ShoppingRemindersMonitor.shared.start()
        WalletActivityMonitor.shared.start()
        Task {
            await ShoppingRemindersMonitor.shared.checkForNewReminders()
            await WalletActivityMonitor.shared.pollIfNeeded(force: true)
            await WidgetSyncService.refreshFromApp()
        }
    }

    static func onEnterBackground() {
        ShoppingRemindersMonitor.shared.stop()
        WalletActivityMonitor.shared.stop()
    }
}
