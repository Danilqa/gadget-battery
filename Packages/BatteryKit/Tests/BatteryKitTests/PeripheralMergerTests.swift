import Testing

@testable import BatteryKit

struct PeripheralMergerTests {
  private func makePeripheral(
    _ name: String, source: Peripheral.Source, percent: Int, address: String? = nil
  ) -> Peripheral {
    Peripheral(
      id: "\(source.rawValue):\(address ?? name)", name: name, kind: .other, source: source,
      cells: [.init(percent: percent)], address: address
    )
  }

  @Test func `keeps the more precise source for the same address`() {
    let merged = PeripheralMerger.merge([
      makePeripheral("Magic Mouse", source: .bluetooth, percent: 50, address: "04:4B:ED:01:02:03"),
      makePeripheral("Magic Mouse", source: .appleHID, percent: 51, address: "04-4b-ed-01-02-03"),
    ])

    #expect(merged.map(\.source) == [.appleHID])
  }

  @Test func `matches a controller without an address by name`() {
    let merged = PeripheralMerger.merge([
      makePeripheral("DualSense Wireless Controller", source: .bluetooth, percent: 40, address: "58:10:31:8B:4F:C4"),
      makePeripheral("DualSense Wireless Controller", source: .gameController, percent: 45),
    ])

    #expect(merged.map(\.source) == [.gameController])
  }

  @Test func `keeps two identical devices with different addresses`() {
    let merged = PeripheralMerger.merge([
      makePeripheral("Magic Keyboard", source: .appleHID, percent: 50, address: "aa:aa:aa:aa:aa:aa"),
      makePeripheral("Magic Keyboard", source: .appleHID, percent: 60, address: "bb:bb:bb:bb:bb:bb"),
    ])

    #expect(merged.count == 2)
  }

  @Test func `keeps two identical controllers from the same source`() {
    let first = makePeripheral("Xbox Wireless Controller", source: .gameController, percent: 50)
    var second = first
    second.id += "#2"

    #expect(PeripheralMerger.merge([first, second]).count == 2)
  }

  @Test func `sorts by name`() {
    let merged = PeripheralMerger.merge([
      makePeripheral("Mouse 10", source: .bluetoothLE, percent: 1),
      makePeripheral("Mouse 2", source: .bluetoothLE, percent: 1),
      makePeripheral("AirPods", source: .bluetooth, percent: 1),
    ])

    #expect(merged.map(\.name) == ["AirPods", "Mouse 2", "Mouse 10"])
  }
}
