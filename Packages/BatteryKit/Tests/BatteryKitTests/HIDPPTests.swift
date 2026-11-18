import Testing

@testable import BatteryKit

struct HIDPPTests {
  private let getFeature = HIDPP.Request(deviceIndex: 1, featureIndex: 0x00, function: 0, parameters: [0x10, 0x04])

  @Test func `encodes a short request with the software id in the low nibble`() {
    #expect(getFeature.encode(isLongReport: false) == [0x10, 0x01, 0x00, 0x0E, 0x10, 0x04, 0x00])
  }

  @Test func `pads a long request to 20 bytes`() {
    let request = HIDPP.Request(deviceIndex: 0xFF, featureIndex: 0x05, function: 1, parameters: [0x10])
    let bytes = request.encode(isLongReport: true)

    #expect(bytes.count == 20)
    #expect(Array(bytes.prefix(5)) == [0x11, 0xFF, 0x05, 0x1E, 0x10])
  }

  @Test func `decodes the matching reply`() {
    let report: [UInt8] = [0x11, 0x01, 0x00, 0x0E, 0x06, 0x00, 0x01] + [UInt8](repeating: 0, count: 13)

    #expect(HIDPP.decodeReply(report, to: getFeature) == .success(parameters: [0x06, 0x00, 0x01] + [UInt8](repeating: 0, count: 13)))
  }

  @Test func `ignores notifications and other devices`() {
    let notification: [UInt8] = [0x11, 0x01, 0x00, 0x00, 0x06, 0x00, 0x01]
    let otherDevice: [UInt8] = [0x11, 0x02, 0x00, 0x0E, 0x06, 0x00, 0x01]

    #expect(HIDPP.decodeReply(notification, to: getFeature) == nil)
    #expect(HIDPP.decodeReply(otherDevice, to: getFeature) == nil)
  }

  @Test func `decodes HID++ 2.0 and 1.0 errors`() {
    let modern: [UInt8] = [0x11, 0x01, 0xFF, 0x00, 0x0E, 0x05, 0x00]
    let legacy: [UInt8] = [0x10, 0x01, 0x8F, 0x00, 0x0E, 0x09, 0x00]

    #expect(HIDPP.decodeReply(modern, to: getFeature) == .failure(code: 0x05, isLegacy: false))
    #expect(HIDPP.decodeReply(legacy, to: getFeature) == .failure(code: 0x09, isLegacy: true))
  }
}

struct HIDPPBatteryTests {
  @Test(arguments: [
    ([50, 30, 0], HIDPP.BatteryReading(percent: 50, isCharging: false)),
    ([50, 30, 1], HIDPP.BatteryReading(percent: 50, isCharging: true)),
    ([90, 0, 3], HIDPP.BatteryReading(percent: 100, isCharging: false)),
    ([20, 0, 4], HIDPP.BatteryReading(percent: 20, isCharging: true)),
  ] as [([UInt8], HIDPP.BatteryReading)])
  func `parses battery status`(parameters: [UInt8], expected: HIDPP.BatteryReading) {
    #expect(HIDPP.parseBatteryStatus(parameters) == expected)
  }

  @Test func `treats an unknown battery status level as missing`() {
    #expect(HIDPP.parseBatteryStatus([0, 0, 0]) == nil)
  }

  @Test(arguments: [
    ([64, 0x04, 0, 0], HIDPP.BatteryReading(percent: 64, isCharging: false)),
    ([64, 0x04, 1, 1], HIDPP.BatteryReading(percent: 64, isCharging: true)),
    ([98, 0x08, 3, 1], HIDPP.BatteryReading(percent: 100, isCharging: false)),
    ([0, 0x02, 0, 0], HIDPP.BatteryReading(percent: 20, isCharging: false)),
  ] as [([UInt8], HIDPP.BatteryReading)])
  func `parses unified battery`(parameters: [UInt8], expected: HIDPP.BatteryReading) {
    #expect(HIDPP.parseUnifiedBattery(parameters) == expected)
  }

  @Test func `parses battery voltage and its charging flags`() {
    // 3859 mV = 0x0F13
    #expect(HIDPP.parseBatteryVoltage([0x0F, 0x13, 0x00]) == .init(percent: 60, isCharging: false))
    #expect(HIDPP.parseBatteryVoltage([0x0F, 0x13, 0x80]) == .init(percent: 60, isCharging: true))
    #expect(HIDPP.parseBatteryVoltage([0x0F, 0x13, 0x81]) == .init(percent: 100, isCharging: false))
    #expect(HIDPP.parseBatteryVoltage([0x0F, 0x13, 0x82]) == .init(percent: 60, isCharging: false))
  }

  @Test(arguments: [(4300, 100), (4186, 100), (3885, 64), (3811, 50), (3500, 0), (3200, 0)])
  func `interpolates the voltage curve`(millivolts: Int, percent: Int) {
    #expect(HIDPP.estimatePercent(millivolts: millivolts) == percent)
  }
}
