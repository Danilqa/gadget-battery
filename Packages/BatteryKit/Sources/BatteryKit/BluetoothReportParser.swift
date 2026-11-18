import Foundation

public enum BluetoothReportParser {
  public static func parsePeripherals(from json: Data) throws -> [Peripheral] {
    let root = try JSONSerialization.jsonObject(with: json) as? [String: Any]
    let controllers = root?["SPBluetoothDataType"] as? [[String: Any]] ?? []
    return controllers.flatMap { controller in
      let connected = controller["device_connected"] as? [[String: Any]] ?? []
      return connected.flatMap { entry in
        entry.compactMap { name, value in
          (value as? [String: Any]).flatMap { buildPeripheral(name: name, properties: $0) }
        }
      }
    }
  }

  static func buildPeripheral(name: String, properties: [String: Any]) -> Peripheral? {
    let partsByKey: [(String, Peripheral.Cell.Part)] = [
      ("device_batteryLevelMain", .main),
      ("device_batteryLevel", .main),
      ("device_batteryLevelLeft", .left),
      ("device_batteryLevelRight", .right),
      ("device_batteryLevelCase", .case),
    ]
    let cells = partsByKey.compactMap { key, part in
      parsePercent(properties[key]).map { Peripheral.Cell(part: part, percent: $0) }
    }
    guard !cells.isEmpty else { return nil }

    let address = properties["device_address"] as? String
    let minorType = properties["device_minorType"] as? String
    return Peripheral(
      id: "bluetooth:" + (address.map(Peripheral.normalizeAddress) ?? name),
      name: name,
      kind: guessKind(minorType: minorType, name: name, hasBuds: cells.contains { $0.part == .left || $0.part == .right }),
      source: .bluetooth,
      cells: deduplicateMain(cells),
      address: address
    )
  }

  static func parsePercent(_ value: Any?) -> Int? {
    switch value {
    case let number as NSNumber: number.intValue
    case let text as String: Int(text.trimmingCharacters(in: CharacterSet(charactersIn: "% ")))
    default: nil
    }
  }

  private static func deduplicateMain(_ cells: [Peripheral.Cell]) -> [Peripheral.Cell] {
    var hasMain = false
    return cells.filter { cell in
      guard cell.part == .main else { return true }
      defer { hasMain = true }
      return !hasMain
    }
  }

  private static func guessKind(minorType: String?, name: String, hasBuds: Bool) -> Peripheral.Kind {
    switch minorType?.lowercased() {
    case "mouse": .mouse
    case "keyboard": .keyboard
    case "magic trackpad", "trackpad": .trackpad
    case "gamepad", "joystick": .controller
    case "headset": .headset
    case "speaker", "loudspeaker", "portable audio": .speaker
    case "headphones":
      hasBuds && !name.lowercased().contains("max") ? .earbuds : .headphones
    default:
      hasBuds ? .earbuds : Peripheral.guessKind(fromName: name)
    }
  }
}
