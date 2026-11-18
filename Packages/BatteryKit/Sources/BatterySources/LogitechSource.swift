import BatteryKit
import Foundation
import IOKit.hid

@MainActor
public final class LogitechSource {
  public var onChange: (() -> Void)?
  public private(set) var blockedProducts: [String] = []

  private let hub = HIDDeviceHub(matching: [
    // Bluetooth devices list the HID++ collection after their mouse or keyboard one.
    [kIOHIDVendorIDKey: HIDPP.vendorID, kIOHIDDeviceUsagePageKey: 0xFF00],
    [kIOHIDVendorIDKey: HIDPP.vendorID, kIOHIDDeviceUsagePageKey: 0xFF43],
  ])
  private var channels: [HIDPPChannel] = []
  private var readings: [String: Peripheral] = [:]
  private var features: [String: [HIDPP.Feature: UInt8]] = [:]
  private var names: [String: (name: String, kind: Peripheral.Kind)] = [:]
  private var pollingChannels: Set<ObjectIdentifier> = []
  private var pendingPoll: Task<Void, Never>?

  public init() {
    hub.onAttach = { [weak self] interface in self?.attach(interface) }
    hub.onDetach = { [weak self] interface in self?.detach(interface) }
  }

  public func start() {
    hub.start()
  }

  public func refresh() {
    blockedProducts = []
    for interface in hub.interfaces where !channels.contains(where: { $0.interface === interface }) {
      attach(interface)
    }
    for channel in channels {
      poll(channel)
    }
  }

  public func readPeripherals() -> [Peripheral] {
    Array(readings.values)
  }

  private func attach(_ interface: HIDInterface) {
    guard !channels.contains(where: { $0.interface === interface }) else { return }
    guard interface.openIfAllowed() else {
      if interface.checkNeedsInputMonitoring() { blockedProducts.append(interface.product) }
      return
    }
    let channel = HIDPPChannel(interface: interface)
    channel.onNotification = { [weak self] _ in self?.schedulePoll() }
    channels.append(channel)
    poll(channel)
  }

  private func detach(_ interface: HIDInterface) {
    channels.removeAll { $0.interface === interface }
    let prefix = makeKeyPrefix(interface)
    readings = readings.filter { !$0.key.hasPrefix(prefix) }
    features = features.filter { !$0.key.hasPrefix(prefix) }
    onChange?()
  }

  // Receivers announce pairing, connection and battery changes in bursts.
  private func schedulePoll() {
    pendingPoll?.cancel()
    pendingPoll = Task { [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled, let self else { return }
      for channel in channels { poll(channel) }
    }
  }

  private func poll(_ channel: HIDPPChannel) {
    let id = ObjectIdentifier(channel)
    guard !pollingChannels.contains(id) else { return }
    pollingChannels.insert(id)
    Task {
      defer { pollingChannels.remove(id) }
      var hasChanged = false
      for deviceIndex in listDeviceIndexes(for: channel.interface) {
        let key = makeKeyPrefix(channel.interface) + String(deviceIndex)
        let peripheral = await readPeripheral(channel: channel, deviceIndex: deviceIndex, key: key)
        if readings[key] != peripheral {
          readings[key] = peripheral
          hasChanged = true
        }
      }
      if hasChanged { onChange?() }
    }
  }

  private func listDeviceIndexes(for interface: HIDInterface) -> [UInt8] {
    let isReceiver = interface.transport == kIOHIDTransportUSBValue && (0xC500...0xC5FF).contains(interface.productID)
    return isReceiver ? Array(1...6) : [HIDPP.directDeviceIndex]
  }

  private func makeKeyPrefix(_ interface: HIDInterface) -> String {
    "\(interface.productID):\(interface.serialNumber ?? String(interface.locationID)):"
  }

  private func readPeripheral(channel: HIDPPChannel, deviceIndex: UInt8, key: String) async -> Peripheral? {
    let timeout: Duration = deviceIndex == HIDPP.directDeviceIndex ? .seconds(2) : .milliseconds(900)
    let ping = HIDPP.Request(deviceIndex: deviceIndex, featureIndex: 0, function: 1, parameters: [0, 0, 0x5A])
    guard case .success = await channel.send(ping, timeout: timeout) else {
      features[key] = nil
      names[key] = nil
      return nil
    }

    var known = features[key] ?? [:]
    let batteryFeatures: [HIDPP.Feature] = [.unifiedBattery, .batteryStatus, .batteryVoltage, .headsetVoltage]
    if known.isEmpty {
      for feature in [HIDPP.Feature.deviceName] + batteryFeatures {
        let request = HIDPP.Request(
          deviceIndex: deviceIndex, featureIndex: 0, function: 0,
          parameters: [UInt8(feature.rawValue >> 8), UInt8(feature.rawValue & 0xFF)]
        )
        if case let .success(parameters) = await channel.send(request, timeout: timeout), let index = parameters.first, index != 0 {
          known[feature] = index
        }
      }
      features[key] = known
    }

    if names[key] == nil, let nameIndex = known[.deviceName] {
      names[key] = await readName(channel: channel, deviceIndex: deviceIndex, featureIndex: nameIndex, timeout: timeout)
    }
    guard let feature = batteryFeatures.first(where: { known[$0] != nil }), let featureIndex = known[feature] else {
      return nil
    }

    let function: UInt8 = feature == .unifiedBattery ? 1 : 0
    let request = HIDPP.Request(deviceIndex: deviceIndex, featureIndex: featureIndex, function: function)
    guard case let .success(parameters) = await channel.send(request, timeout: timeout) else { return nil }
    let reading: HIDPP.BatteryReading? = switch feature {
    case .unifiedBattery: HIDPP.parseUnifiedBattery(parameters)
    case .batteryStatus: HIDPP.parseBatteryStatus(parameters)
    case .batteryVoltage: HIDPP.parseBatteryVoltage(parameters)
    case .headsetVoltage: HIDPP.parseHeadsetVoltage(parameters)
    default: nil
    }
    guard let reading else { return nil }

    let fallbackName = channel.interface.product.isEmpty ? "Logitech device" : channel.interface.product
    let identity = names[key] ?? (fallbackName, Peripheral.guessKind(fromName: fallbackName))
    return Peripheral(
      id: "logitech:\(key)",
      name: identity.name,
      kind: identity.kind,
      source: .logitech,
      cells: [Peripheral.Cell(percent: reading.percent, isCharging: reading.isCharging)]
    )
  }

  private func readName(
    channel: HIDPPChannel, deviceIndex: UInt8, featureIndex: UInt8, timeout: Duration
  ) async -> (name: String, kind: Peripheral.Kind)? {
    let countRequest = HIDPP.Request(deviceIndex: deviceIndex, featureIndex: featureIndex, function: 0)
    guard case let .success(countReply) = await channel.send(countRequest, timeout: timeout),
      let length = countReply.first.map(Int.init), length > 0
    else { return nil }

    var bytes: [UInt8] = []
    while bytes.count < length {
      let request = HIDPP.Request(
        deviceIndex: deviceIndex, featureIndex: featureIndex, function: 1, parameters: [UInt8(bytes.count)]
      )
      guard case let .success(chunk) = await channel.send(request, timeout: timeout) else { return nil }
      let characters = chunk.prefix(length - bytes.count).prefix { $0 != 0 }
      guard !characters.isEmpty else { break }
      bytes += characters
    }
    guard let name = String(bytes: bytes, encoding: .utf8)?.trimmingCharacters(in: .whitespaces), !name.isEmpty else {
      return nil
    }

    let typeRequest = HIDPP.Request(deviceIndex: deviceIndex, featureIndex: featureIndex, function: 2)
    var kind = Peripheral.guessKind(fromName: name)
    if case let .success(typeReply) = await channel.send(typeRequest, timeout: timeout), let type = typeReply.first {
      kind = HIDPP.convertDeviceType(type) ?? kind
    }
    return (name, kind)
  }
}
