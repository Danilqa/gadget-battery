import BatteryKit
import Foundation
import IOKit.hid

@MainActor
public final class RazerSource {
  public var onChange: (() -> Void)?
  public private(set) var blockedProducts: [String] = []

  private let hub = HIDDeviceHub(matching: [
    [kIOHIDVendorIDKey: RazerProtocol.vendorID, kIOHIDPrimaryUsagePageKey: 0x01, kIOHIDPrimaryUsageKey: 0x02]
  ])
  private var readings: [String: Peripheral] = [:]
  private var isPolling = false

  public init() {
    hub.onDetach = { [weak self] _ in self?.refresh() }
    hub.onAttach = { [weak self] _ in self?.refresh() }
  }

  public func start() {
    hub.start()
  }

  public func readPeripherals() -> [Peripheral] {
    Array(readings.values)
  }

  public func refresh() {
    guard !isPolling else { return }
    isPolling = true
    Task {
      defer { isPolling = false }
      var fresh: [String: Peripheral] = [:]
      var blocked: [String] = []
      for interface in hub.interfaces {
        guard let model = RazerProtocol.models[interface.productID] else { continue }
        guard interface.openIfAllowed() else {
          blocked.append(model.name)
          continue
        }
        let key = "\(interface.productID):\(interface.serialNumber ?? String(interface.locationID))"
        // A receiver can expose several mouse interfaces; the first one that answers wins.
        guard fresh[key] == nil, let peripheral = await readPeripheral(interface: interface, model: model, key: key) else {
          continue
        }
        fresh[key] = peripheral
      }
      blockedProducts = blocked
      if fresh != readings {
        readings = fresh
        onChange?()
      }
    }
  }

  private func readPeripheral(interface: HIDInterface, model: RazerProtocol.Model, key: String) async -> Peripheral? {
    guard let level = await send(.batteryLevel, to: interface, model: model), level > 0 else { return nil }
    let isCharging = await send(.chargingStatus, to: interface, model: model) == 1
    return Peripheral(
      id: "razer:\(key)",
      name: model.name,
      kind: model.kind,
      source: .razer,
      cells: [Peripheral.Cell(percent: RazerProtocol.convertToPercent(level), isCharging: isCharging)]
    )
  }

  // Retries a busy receiver five times, 10 ms apart, like openrazer.
  private func send(_ command: RazerProtocol.Command, to interface: HIDInterface, model: RazerProtocol.Model) async -> UInt8? {
    let request = RazerProtocol.buildRequest(command, transactionID: model.transactionID)
    guard interface.sendFeatureReport(request, reportID: 0) else { return nil }
    try? await Task.sleep(for: .microseconds(model.replyDelayMicroseconds))
    for _ in 0..<5 {
      guard let reply = interface.readFeatureReport(length: RazerProtocol.reportLength, reportID: 0) else { return nil }
      switch RazerProtocol.decodeReply(reply, to: command) {
      case let .value(value):
        return value
      case .status(.busy):
        try? await Task.sleep(for: .milliseconds(10))
      case .status:
        return nil
      }
    }
    return nil
  }
}
