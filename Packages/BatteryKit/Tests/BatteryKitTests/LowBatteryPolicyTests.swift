import Testing

@testable import BatteryKit

struct LowBatteryPolicyTests {
  private func makeMouse(_ percent: Int, isCharging: Bool = false) -> Peripheral {
    Peripheral(id: "mouse", name: "Mouse", kind: .mouse, source: .appleHID, cells: [.init(percent: percent, isCharging: isCharging)])
  }

  @Test func `warns once when a device drops to the threshold`() {
    var policy = LowBatteryPolicy(threshold: 20)

    #expect(policy.evaluate([makeMouse(25)]).isEmpty)
    #expect(policy.evaluate([makeMouse(20)]).map(\.severity) == [.low])
    #expect(policy.evaluate([makeMouse(18)]).isEmpty)
  }

  @Test func `warns again when the device turns critical`() {
    var policy = LowBatteryPolicy(threshold: 20)

    _ = policy.evaluate([makeMouse(19)])

    #expect(policy.evaluate([makeMouse(10)]).map(\.severity) == [.critical])
    #expect(policy.evaluate([makeMouse(9)]).isEmpty)
  }

  @Test func `jumps straight to critical without a low warning first`() {
    var policy = LowBatteryPolicy(threshold: 20)

    #expect(policy.evaluate([makeMouse(4)]).map(\.severity) == [.critical])
  }

  @Test func `stays quiet while charging and rearms after a charge`() {
    var policy = LowBatteryPolicy(threshold: 20)

    _ = policy.evaluate([makeMouse(15)])
    #expect(policy.evaluate([makeMouse(15, isCharging: true)]).isEmpty)
    #expect(policy.evaluate([makeMouse(15)]).map(\.severity) == [.low])
  }

  @Test func `does not rearm on a small bounce above the threshold`() {
    var policy = LowBatteryPolicy(threshold: 20)

    _ = policy.evaluate([makeMouse(20)])
    #expect(policy.evaluate([makeMouse(23)]).isEmpty)
    #expect(policy.evaluate([makeMouse(20)]).isEmpty)
    #expect(policy.evaluate([makeMouse(26)]).isEmpty)
    #expect(policy.evaluate([makeMouse(20)]).map(\.severity) == [.low])
  }
}
