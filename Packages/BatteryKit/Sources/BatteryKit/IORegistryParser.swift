import Foundation

public enum IORegistryParser {
  public static func buildPeripheral(properties: [String: Any]) -> Peripheral? {
    guard let percent = (properties["BatteryPercent"] as? NSNumber)?.intValue,
      let name = (properties["Product"] as? String) ?? (properties["DeviceName"] as? String),
      !name.contains("Internal")
    else { return nil }

    let address = properties["DeviceAddress"] as? String
    let serial = properties["SerialNumber"] as? String
    let identity = address.map(Peripheral.normalizeAddress) ?? serial ?? name
    return Peripheral(
      id: "hid:\(identity)",
      name: name,
      kind: guessKind(properties: properties, name: name),
      source: .appleHID,
      cells: [Peripheral.Cell(percent: percent, isCharging: checkIsCharging(properties))],
      address: address
    )
  }

  // Undocumented; AirBattery reads 4 as discharging and other non-zero values as charging.
  static func checkIsCharging(_ properties: [String: Any]) -> Bool {
    guard let flags = (properties["BatteryStatusFlags"] as? NSNumber)?.intValue else { return false }
    return flags != 0 && flags != 4
  }

  private static func guessKind(properties: [String: Any], name: String) -> Peripheral.Kind {
    let page = (properties["PrimaryUsagePage"] as? NSNumber)?.intValue
    let usage = (properties["PrimaryUsage"] as? NSNumber)?.intValue
    let byName = Peripheral.guessKind(fromName: name)
    guard byName == .other, page == 0x01 else { return byName }
    return switch usage {
    case 0x02: .mouse
    case 0x06: .keyboard
    case 0x04, 0x05: .controller
    default: .other
    }
  }
}
