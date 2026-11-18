import BatteryKit
import BatterySources
import AppKit
import Observation
import WidgetKit
import os

@Observable
final class BatteryMonitor {
  static let refreshInterval: Duration = .seconds(60)

  private(set) var peripherals: [Peripheral] = []
  private(set) var updatedAt: Date?
  private(set) var isRefreshing = false
  private(set) var blockedProducts: [String] = []
  private var isRefreshPending = false
  private var hasPublished = false

  private let preferences: Preferences
  private let notifier: LowBatteryNotifier
  private let snapshotStore = SnapshotStore(appGroup: AppGroup.identifier)
  private let bluetoothReport = BluetoothReportSource()
  private let gameControllers = GameControllerSource()
  private let bluetoothLE = BluetoothLESource()
  private let ioRegistry = IORegistrySource()
  private let logitech = LogitechSource()
  private let razer = RazerSource()
  private var policy: LowBatteryPolicy
  private var pollTask: Task<Void, Never>?
  private var pendingRefresh: Task<Void, Never>?
  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app", category: "Monitor")

  var visiblePeripherals: [Peripheral] {
    peripherals.filter { !preferences.hiddenIDs.contains($0.id) }
  }

  var lowestPeripheral: Peripheral? {
    visiblePeripherals.min { ($0.percent ?? 101) < ($1.percent ?? 101) }
  }

  init(preferences: Preferences, notifier: LowBatteryNotifier) {
    self.preferences = preferences
    self.notifier = notifier
    policy = LowBatteryPolicy(threshold: preferences.threshold)
    if let snapshot = snapshotStore.load() {
      peripherals = snapshot.peripherals
      updatedAt = snapshot.updatedAt
    }
    gameControllers.onChange = { [weak self] in self?.scheduleRefresh() }
    bluetoothLE.onChange = { [weak self] in self?.scheduleRefresh() }
    logitech.onChange = { [weak self] in self?.scheduleRefresh() }
    razer.onChange = { [weak self] in self?.scheduleRefresh() }
  }

  func start() {
    if UserDefaults.standard.bool(forKey: "demo") {
      apply(PeripheralMerger.merge(Snapshot.sample.peripherals))
      return
    }
    bluetoothLE.start()
    logitech.start()
    razer.start()
    pollTask?.cancel()
    pollTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.refresh()
        try? await Task.sleep(for: Self.refreshInterval)
      }
    }
  }

  func refresh() async {
    guard !UserDefaults.standard.bool(forKey: "demo") else { return }
    if isRefreshing {
      isRefreshPending = true
      return
    }
    isRefreshing = true
    defer { isRefreshing = false }
    repeat {
      isRefreshPending = false
      await readAllSources()
    } while isRefreshPending
  }

  private func readAllSources() async {
    bluetoothLE.refresh()
    logitech.refresh()
    razer.refresh()
    let reported = await bluetoothReport.readPeripherals()
    let merged = PeripheralMerger.merge(
      ioRegistry.readPeripherals()
        + gameControllers.readPeripherals()
        + bluetoothLE.readPeripherals()
        + logitech.readPeripherals()
        + razer.readPeripherals()
        + reported
    )
    blockedProducts = Array(Set(logitech.blockedProducts + razer.blockedProducts)).sorted()
    apply(merged)
  }

  func requestInputMonitoring() {
    if !InputMonitoring.request(), let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
      NSWorkspace.shared.open(url)
    }
    Task { await refresh() }
  }

  func applyThreshold() {
    policy.threshold = preferences.threshold
    evaluateAlerts()
    publishSnapshot()
  }

  func publishSnapshot() {
    let snapshot = Snapshot(peripherals: visiblePeripherals, threshold: preferences.threshold, updatedAt: updatedAt ?? .now)
    do {
      try snapshotStore.save(snapshot)
      hasPublished = true
      WidgetCenter.shared.reloadAllTimelines()
    } catch {
      logger.error("Saving the widget snapshot failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  private func apply(_ merged: [Peripheral]) {
    let hasChanged = merged != peripherals
    peripherals = merged
    updatedAt = .now
    evaluateAlerts()
    if hasChanged || !hasPublished {
      publishSnapshot()
    }
  }

  private func evaluateAlerts() {
    let alerts = policy.evaluate(visiblePeripherals)
    guard preferences.areNotificationsEnabled else { return }
    for alert in alerts {
      notifier.post(alert)
    }
  }

  // Several sources fire at once when a device connects.
  private func scheduleRefresh() {
    pendingRefresh?.cancel()
    pendingRefresh = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(500))
      guard !Task.isCancelled else { return }
      await self?.refresh()
    }
  }
}
