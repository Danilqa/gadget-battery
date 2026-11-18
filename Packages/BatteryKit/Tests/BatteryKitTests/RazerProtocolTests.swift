import Testing

@testable import BatteryKit

struct RazerProtocolTests {
  @Test func `builds the battery request with openrazer's checksum`() {
    let report = RazerProtocol.buildRequest(.batteryLevel, transactionID: 0x1F)

    #expect(report.count == 90)
    #expect(Array(report.prefix(8)) == [0x00, 0x1F, 0x00, 0x00, 0x00, 0x02, 0x07, 0x80])
    #expect(report[88] == 0x85)
  }

  @Test func `builds the charging request`() {
    #expect(RazerProtocol.buildRequest(.chargingStatus, transactionID: 0x3F)[88] == 0x81)
  }

  @Test func `reads the value from a successful reply`() {
    var reply = RazerProtocol.buildRequest(.batteryLevel, transactionID: 0x1F)
    reply[0] = RazerProtocol.Status.success.rawValue
    reply[9] = 0xBF

    #expect(RazerProtocol.decodeReply(reply, to: .batteryLevel) == .value(0xBF))
    #expect(RazerProtocol.decodeReply(reply, to: .chargingStatus) == .status(.success))
  }

  @Test func `reports a busy receiver`() {
    var reply = RazerProtocol.buildRequest(.batteryLevel, transactionID: 0x1F)
    reply[0] = RazerProtocol.Status.busy.rawValue

    #expect(RazerProtocol.decodeReply(reply, to: .batteryLevel) == .status(.busy))
  }

  @Test(arguments: [(UInt8(0), 0), (255, 100), (191, 75)])
  func `scales the level to percent`(level: UInt8, percent: Int) {
    #expect(RazerProtocol.convertToPercent(level) == percent)
  }
}
