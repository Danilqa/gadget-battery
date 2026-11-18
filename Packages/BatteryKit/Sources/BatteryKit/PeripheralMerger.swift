import Foundation

public enum PeripheralMerger {
  public static let sourcePriority: [Peripheral.Source] = [
    .logitech, .razer, .appleHID, .gameController, .bluetooth, .bluetoothLE,
  ]

  public static func merge(_ peripherals: [Peripheral]) -> [Peripheral] {
    let ordered = peripherals.enumerated().sorted { lhs, rhs in
      let lhsRank = rank(lhs.element.source)
      let rhsRank = rank(rhs.element.source)
      return lhsRank == rhsRank ? lhs.offset < rhs.offset : lhsRank < rhsRank
    }
    var kept: [Peripheral] = []
    for (_, candidate) in ordered {
      guard let index = kept.firstIndex(where: { checkIsSameDevice($0, candidate) }) else {
        kept.append(candidate)
        continue
      }
      // The Bluetooth report has the name the user gave the device.
      if candidate.source == .bluetooth, kept[index].address != nil, kept[index].address == candidate.address {
        kept[index].name = candidate.name
      }
    }
    return kept.sorted { lhs, rhs in
      lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
  }

  static func checkIsSameDevice(_ lhs: Peripheral, _ rhs: Peripheral) -> Bool {
    if lhs.id == rhs.id { return true }
    if let lhsAddress = lhs.address, let rhsAddress = rhs.address {
      return lhsAddress == rhsAddress
    }
    return lhs.source != rhs.source && Peripheral.normalizeName(lhs.name) == Peripheral.normalizeName(rhs.name)
  }

  private static func rank(_ source: Peripheral.Source) -> Int {
    sourcePriority.firstIndex(of: source) ?? sourcePriority.count
  }
}
