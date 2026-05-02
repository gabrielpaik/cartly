import FirebaseMessaging
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, MessagingDelegate {
  private static let lastRegistrationErrorDefaultsKey = "push_debug_last_registration_error"

  private weak var applicationRef: UIApplication?
  private var pushChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    applicationRef = application
    UNUserNotificationCenter.current().delegate = self
    Messaging.messaging().delegate = self
    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    application.registerForRemoteNotifications()
    return didFinish
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    UserDefaults.standard.removeObject(forKey: Self.lastRegistrationErrorDefaultsKey)
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    UserDefaults.standard.set(error.localizedDescription, forKey: Self.lastRegistrationErrorDefaultsKey)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    configurePushChannel(engineBridge)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if let targetTab = extractTargetTab(from: notification.request.content.userInfo) {
      pushChannel?.invokeMethod("foregroundNotificationReceived", arguments: ["targetTab": targetTab])
    }
    completionHandler([.banner, .badge, .sound])
  }

  private func configurePushChannel(_ engineBridge: FlutterImplicitEngineBridge) {
    guard pushChannel == nil else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "cartly/push",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "APP_DELEGATE_DEALLOCATED", message: nil, details: nil))
        return
      }
      switch call.method {
      case "registerForRemoteNotifications":
        DispatchQueue.main.async {
          self.applicationRef?.registerForRemoteNotifications()
          result(true)
        }
      case "isRegisteredForRemoteNotifications":
        result(self.applicationRef?.isRegisteredForRemoteNotifications)
      case "lastRemoteNotificationRegistrationError":
        result(UserDefaults.standard.string(forKey: Self.lastRegistrationErrorDefaultsKey))
      case "latestDeliveredTargetTab":
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
          let targetTab = notifications.reversed().compactMap {
            self.extractTargetTab(from: $0.request.content.userInfo)
          }.first
          result(targetTab)
        }
      case "clearDeliveredNotificationsForTargetTab":
        let targetTab = (call.arguments as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
          let identifiers = notifications.compactMap { notification -> String? in
            guard self.extractTargetTab(from: notification.request.content.userInfo) == targetTab else {
              return nil
            }
            return notification.request.identifier
          }
          if !identifiers.isEmpty {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
          }
          DispatchQueue.main.async {
            self.applicationRef?.applicationIconBadgeNumber = 0
          }
          result(true)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    pushChannel = channel
  }

  private func extractTargetTab(from userInfo: [AnyHashable: Any]) -> String? {
    guard let value = userInfo["targetTab"] as? String else {
      return nil
    }
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    switch normalized {
    case "home", "explore", "my":
      return normalized
    default:
      return nil
    }
  }
}
