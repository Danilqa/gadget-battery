import Foundation
import Observation
import ServiceManagement
import os

@Observable
final class Preferences {
  private enum Key {
    static let threshold = "lowBatteryThreshold"
    static let areNotificationsEnabled = "notificationsEnabled"
    static let isPercentInMenuBar = "showsPercentInMenuBar"
    static let hiddenIDs = "hiddenPeripheralIDs"
  }

  static let thresholdRange = 5...50

  private let defaults: UserDefaults

  var threshold: Int {
    didSet { defaults.set(threshold, forKey: Key.threshold) }
  }

  var areNotificationsEnabled: Bool {
    didSet { defaults.set(areNotificationsEnabled, forKey: Key.areNotificationsEnabled) }
  }

  var isPercentInMenuBar: Bool {
    didSet { defaults.set(isPercentInMenuBar, forKey: Key.isPercentInMenuBar) }
  }

  var hiddenIDs: Set<String> {
    didSet { defaults.set(hiddenIDs.sorted(), forKey: Key.hiddenIDs) }
  }

  var isLaunchedAtLogin: Bool {
    get {
      access(keyPath: \.isLaunchedAtLogin)
      return SMAppService.mainApp.status == .enabled
    }
    set {
      withMutation(keyPath: \.isLaunchedAtLogin) {
        do {
          if newValue {
            try SMAppService.mainApp.register()
          } else {
            try SMAppService.mainApp.unregister()
          }
        } catch {
          Logger(subsystem: Bundle.main.bundleIdentifier ?? "app", category: "Preferences")
            .error("Launch at login change failed: \(error.localizedDescription, privacy: .public)")
        }
      }
    }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    defaults.register(defaults: [
      Key.threshold: 20,
      Key.areNotificationsEnabled: true,
      Key.isPercentInMenuBar: true,
    ])
    threshold = defaults.integer(forKey: Key.threshold)
    areNotificationsEnabled = defaults.bool(forKey: Key.areNotificationsEnabled)
    isPercentInMenuBar = defaults.bool(forKey: Key.isPercentInMenuBar)
    hiddenIDs = Set(defaults.stringArray(forKey: Key.hiddenIDs) ?? [])
  }
}
