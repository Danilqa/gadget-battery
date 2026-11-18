import BatteryKit
import Foundation
import GameController

@MainActor
public final class GameControllerSource {
  public var onChange: (() -> Void)?
  private var observers: [any NSObjectProtocol] = []

  public init() {
    // A menu bar app is never frontmost; without this the framework hides controllers.
    GCController.shouldMonitorBackgroundEvents = true
    let center = NotificationCenter.default
    for name in [Notification.Name.GCControllerDidConnect, .GCControllerDidDisconnect] {
      observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.onChange?() }
      })
    }
  }

  public func readPeripherals() -> [Peripheral] {
    var seen: [String: Int] = [:]
    return GCController.controllers().compactMap { controller in
      guard let battery = controller.battery, battery.batteryState != .unknown || battery.batteryLevel > 0 else {
        return nil
      }
      let name = controller.vendorName ?? controller.productCategory
      let slug = name.lowercased().filter { $0.isLetter || $0.isNumber }
      seen[slug, default: 0] += 1
      let suffix = seen[slug, default: 1] > 1 ? "#\(seen[slug, default: 1])" : ""
      return Peripheral(
        id: "controller:\(slug)\(suffix)",
        name: name,
        kind: .controller,
        source: .gameController,
        cells: [
          Peripheral.Cell(
            percent: Int((battery.batteryLevel * 100).rounded()),
            isCharging: battery.batteryState == .charging
          )
        ]
      )
    }
  }
}
