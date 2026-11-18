import BatteryKit
import Foundation
import UserNotifications

final class LowBatteryNotifier: NSObject {
  private let center = UNUserNotificationCenter.current()

  override init() {
    super.init()
    center.delegate = self
  }

  func requestAuthorization() {
    center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
  }

  func post(_ alert: LowBatteryPolicy.Alert) {
    let peripheral = alert.peripheral
    let content = UNMutableNotificationContent()
    content.title = String(localized: "\(peripheral.name) is at \(peripheral.percent ?? 0)%")
    content.body = switch alert.severity {
    case .low: String(localized: "Charge it soon.")
    case .critical: String(localized: "It will turn off soon. Charge it now.")
    }
    content.sound = .default
    content.threadIdentifier = peripheral.id
    let request = UNNotificationRequest(identifier: "low-battery-\(peripheral.id)", content: content, trigger: nil)
    center.add(request)
  }
}

extension LowBatteryNotifier: UNUserNotificationCenterDelegate {
  // The menu bar panel makes the app active; show the warning even then.
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .sound]
  }
}
