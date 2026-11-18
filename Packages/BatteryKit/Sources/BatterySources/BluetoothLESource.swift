import BatteryKit
import CoreBluetooth
import Foundation

@MainActor
public final class BluetoothLESource: NSObject {
  private static let batteryService = CBUUID(string: "180F")
  private static let batteryLevel = CBUUID(string: "2A19")

  public var onChange: (() -> Void)?
  private var central: CBCentralManager?
  private var tracked: [UUID: CBPeripheral] = [:]
  private var levels: [UUID: Int] = [:]

  public override init() {
    super.init()
  }

  // Starting asks for Bluetooth permission.
  public func start() {
    guard central == nil else { return }
    central = CBCentralManager(delegate: self, queue: .main)
  }

  public func refresh() {
    guard let central, central.state == .poweredOn else { return }
    let connected = central.retrieveConnectedPeripherals(withServices: [Self.batteryService])
    let connectedIDs = Set(connected.map(\.identifier))
    for (id, peripheral) in tracked where !connectedIDs.contains(id) {
      central.cancelPeripheralConnection(peripheral)
      tracked[id] = nil
      levels[id] = nil
    }
    for peripheral in connected {
      if tracked[peripheral.identifier] == nil {
        tracked[peripheral.identifier] = peripheral
        peripheral.delegate = self
      }
      if peripheral.state == .connected {
        readLevel(of: peripheral)
      } else {
        central.connect(peripheral)
      }
    }
  }

  public func readPeripherals() -> [Peripheral] {
    tracked.compactMap { id, peripheral in
      guard let percent = levels[id] else { return nil }
      let name = peripheral.name ?? "Bluetooth device"
      return Peripheral(
        id: "ble:\(id.uuidString)",
        name: name,
        kind: Peripheral.guessKind(fromName: name),
        source: .bluetoothLE,
        cells: [Peripheral.Cell(percent: percent)]
      )
    }
  }

  private func readLevel(of peripheral: CBPeripheral) {
    let characteristic = peripheral.services?
      .first { $0.uuid == Self.batteryService }?
      .characteristics?
      .first { $0.uuid == Self.batteryLevel }
    if let characteristic {
      peripheral.readValue(for: characteristic)
    } else {
      peripheral.discoverServices([Self.batteryService])
    }
  }
}

extension BluetoothLESource: @preconcurrency CBCentralManagerDelegate {
  public func centralManagerDidUpdateState(_ central: CBCentralManager) {
    refresh()
  }

  public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    readLevel(of: peripheral)
  }

  public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
    guard levels.removeValue(forKey: peripheral.identifier) != nil else { return }
    onChange?()
  }
}

extension BluetoothLESource: @preconcurrency CBPeripheralDelegate {
  public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
    guard let service = peripheral.services?.first(where: { $0.uuid == Self.batteryService }) else { return }
    peripheral.discoverCharacteristics([Self.batteryLevel], for: service)
  }

  public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
    guard let characteristic = service.characteristics?.first(where: { $0.uuid == Self.batteryLevel }) else { return }
    peripheral.readValue(for: characteristic)
    if characteristic.properties.contains(.notify) {
      peripheral.setNotifyValue(true, for: characteristic)
    }
  }

  public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
    guard characteristic.uuid == Self.batteryLevel, let byte = characteristic.value?.first else { return }
    let percent = Int(byte)
    guard levels[peripheral.identifier] != percent else { return }
    levels[peripheral.identifier] = percent
    onChange?()
  }
}
