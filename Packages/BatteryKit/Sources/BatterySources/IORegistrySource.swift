import BatteryKit
import Foundation
import IOKit

public struct IORegistrySource: Sendable {
  public init() {}

  public func readPeripherals() -> [Peripheral] {
    let matching = [kIOPropertyExistsMatchKey: "BatteryPercent"] as CFDictionary
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return [] }
    defer { IOObjectRelease(iterator) }

    var peripherals: [Peripheral] = []
    while case let service = IOIteratorNext(iterator), service != 0 {
      defer { IOObjectRelease(service) }
      var properties: Unmanaged<CFMutableDictionary>?
      guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
        let dictionary = properties?.takeRetainedValue() as? [String: Any],
        let peripheral = IORegistryParser.buildPeripheral(properties: dictionary)
      else { continue }
      peripherals.append(peripheral)
    }
    return peripherals
  }
}
