import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UNUserNotificationCenterDelegate {
  private var isNotificationChannelRegistered = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self

    if let controller = window?.rootViewController as? FlutterViewController {
      registerNotificationChannel(with: controller.binaryMessenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "dev.moodify.moodify_flutter/notifications")
    registerNotificationChannel(with: registrar.messenger())
  }

  private func registerNotificationChannel(with messenger: FlutterBinaryMessenger) {
    guard !isNotificationChannelRegistered else { return }
    isNotificationChannelRegistered = true

    let channel = FlutterMethodChannel(
      name: "dev.moodify.moodify_flutter/notifications",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      self?.handleNotificationMethodCall(call: call, result: result)
    }
  }

  private func handleNotificationMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "ensurePermission":
      ensureNotificationPermission(result: result)
    case "showNotification":
      showLocalNotification(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func ensureNotificationPermission(result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      switch settings.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
        DispatchQueue.main.async {
          result(true)
        }
      case .notDetermined:
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
          DispatchQueue.main.async {
            result(granted)
          }
        }
      case .denied:
        DispatchQueue.main.async {
          result(false)
        }
      @unknown default:
        DispatchQueue.main.async {
          result(false)
        }
      }
    }
  }

  private func showLocalNotification(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(false)
      return
    }
    let id = (args["id"] as? String) ?? UUID().uuidString
    let title = (args["title"] as? String) ?? "Moodify"
    let message = (args["message"] as? String) ?? ""
    let silent = (args["silent"] as? Bool) ?? false

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = message
    if !silent {
      content.sound = UNNotificationSound.default
    }

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
    let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

    UNUserNotificationCenter.current().add(request) { error in
      DispatchQueue.main.async {
        if let error = error {
          NSLog("Moodify iOS Notification error: %@", error.localizedDescription)
          result(false)
        } else {
          result(true)
        }
      }
    }
  }

  // MARK: - UNUserNotificationCenterDelegate

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .badge, .sound, .list])
    } else {
      completionHandler([.alert, .badge, .sound])
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }
}
