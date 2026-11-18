import BatteryKit
import SwiftUI

@main
struct GadgetBatteryApp: App {
  @State private var preferences: Preferences
  @State private var monitor: BatteryMonitor

  init() {
    let preferences = Preferences()
    let notifier = LowBatteryNotifier()
    let monitor = BatteryMonitor(preferences: preferences, notifier: notifier)
    _preferences = State(initialValue: preferences)
    _monitor = State(initialValue: monitor)
    if preferences.areNotificationsEnabled {
      notifier.requestAuthorization()
    }
    monitor.start()
    #if DEBUG
    PanelSnapshot.writeIfRequested(monitor: monitor, preferences: preferences)
    #endif
  }

  var body: some Scene {
    MenuBarExtra {
      MenuContentView()
        .environment(monitor)
        .environment(preferences)
    } label: {
      MenuBarLabel()
        .environment(monitor)
        .environment(preferences)
    }
    .menuBarExtraStyle(.window)

    Settings {
      SettingsView()
        .environment(monitor)
        .environment(preferences)
    }
  }
}
