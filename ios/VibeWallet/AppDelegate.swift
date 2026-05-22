import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task { @MainActor in
            VibeNotificationService.configure()
        }
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        routeNotification(userInfo: response.notification.request.content.userInfo)
    }

    private func routeNotification(userInfo: [AnyHashable: Any]) {
        guard let link = VibeDeepLink.from(userInfo: userInfo) else { return }
        NotificationCenter.default.post(name: .vibeOpenDeepLink, object: link)
    }
}
