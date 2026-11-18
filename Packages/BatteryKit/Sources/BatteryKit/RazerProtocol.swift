import Foundation

// Layout from openrazer's razercommon.h.
public enum RazerProtocol {
  public static let vendorID = 0x1532
  public static let reportLength = 90

  public enum Status: UInt8, Sendable {
    case new = 0x00, busy = 0x01, success = 0x02, failure = 0x03, timeout = 0x04, notSupported = 0x05
  }

  public enum Command: Sendable {
    case batteryLevel, chargingStatus

    var commandClass: UInt8 { 0x07 }
    var commandID: UInt8 {
      switch self {
      case .batteryLevel: 0x80
      case .chargingStatus: 0x84
      }
    }
  }

  public static func buildRequest(_ command: Command, transactionID: UInt8) -> [UInt8] {
    var report = [UInt8](repeating: 0, count: reportLength)
    report[1] = transactionID
    report[5] = 0x02
    report[6] = command.commandClass
    report[7] = command.commandID
    report[88] = computeChecksum(report)
    return report
  }

  public static func computeChecksum(_ report: [UInt8]) -> UInt8 {
    report[2...87].reduce(0, ^)
  }

  public enum Reply: Equatable, Sendable {
    case value(UInt8)
    case status(Status?)
  }

  public static func decodeReply(_ report: [UInt8], to command: Command) -> Reply {
    guard report.count >= reportLength else { return .status(nil) }
    let status = Status(rawValue: report[0])
    guard status == .success, report[6] == command.commandClass, report[7] == command.commandID else {
      return .status(status)
    }
    return .value(report[9])
  }

  public static func convertToPercent(_ level: UInt8) -> Int {
    Int((Double(level) / 255 * 100).rounded())
  }

  public struct Model: Sendable {
    public var name: String
    public var kind: Peripheral.Kind
    public var transactionID: UInt8
    public var replyDelayMicroseconds: Int
  }

  // From openrazer's mouse driver.
  public static let models: [Int: Model] = {
    var models: [Int: Model] = [:]
    func add(_ name: String, _ ids: [Int], transactionID: UInt8, replyDelayMicroseconds: Int = 31_000, kind: Peripheral.Kind = .mouse) {
      for id in ids {
        models[id] = Model(name: name, kind: kind, transactionID: transactionID, replyDelayMicroseconds: replyDelayMicroseconds)
      }
    }
    add("Razer Mamba Wireless", [0x0072, 0x0073], transactionID: 0x3F)
    add("Razer DeathAdder V2 Pro", [0x007C, 0x007D], transactionID: 0x3F, replyDelayMicroseconds: 59_900)
    add("Razer Lancehead Wireless", [0x005A], transactionID: 0x3F)
    add("Razer Viper V2 Pro", [0x00A5, 0x00A6], transactionID: 0x1F)
    add("Razer Viper V3 Pro", [0x00C0, 0x00C1], transactionID: 0x1F, replyDelayMicroseconds: 59_900)
    add("Razer Viper V3 Pro SE", [0x00DE, 0x00DF], transactionID: 0x1F)
    add("Razer Viper V3 HyperSpeed", [0x00B8], transactionID: 0x1F)
    add("Razer Viper V4 Pro", [0x00E5, 0x00E6], transactionID: 0x1F)
    add("Razer Viper Mini SE", [0x009E, 0x009F], transactionID: 0x1F)
    add("Razer DeathAdder V3 Pro", [0x00B6, 0x00B7, 0x00C2, 0x00C3], transactionID: 0x1F)
    add("Razer DeathAdder V3 HyperSpeed", [0x00C4, 0x00C5], transactionID: 0x1F)
    add("Razer DeathAdder V4 Pro", [0x00BE, 0x00BF], transactionID: 0x1F)
    add("Razer DeathAdder V2 X HyperSpeed", [0x009C], transactionID: 0x1F)
    add("Razer Basilisk Ultimate", [0x0086, 0x0088], transactionID: 0x1F)
    add("Razer Basilisk V3 Pro", [0x00AA, 0x00AB], transactionID: 0x1F)
    add("Razer Basilisk V3 Pro 35K", [0x00CC, 0x00CD], transactionID: 0x1F)
    add("Razer Basilisk V3 X HyperSpeed", [0x00B9], transactionID: 0x1F)
    add("Razer Naga Pro", [0x008F, 0x0090], transactionID: 0x1F)
    add("Razer Naga V2 Pro", [0x00A7, 0x00A8], transactionID: 0x1F)
    add("Razer Naga V2 HyperSpeed", [0x00B4], transactionID: 0x1F)
    add("Razer Orochi V2", [0x0094, 0x0095, 0x00E0], transactionID: 0x1F, replyDelayMicroseconds: 400_000)
    add("Razer Cobra Pro", [0x00AF, 0x00B0], transactionID: 0x1F)
    add("Razer Cobra HyperSpeed", [0x00DA, 0x00DB], transactionID: 0x1F)
    add("Razer Atheris", [0x0062], transactionID: 0x1F, replyDelayMicroseconds: 400_000)
    add("Razer Pro Click", [0x0077, 0x0080], transactionID: 0x1F)
    add("Razer Pro Click Mini", [0x009A], transactionID: 0x1F)
    add("Razer HyperPolling Wireless Dongle", [0x00B3], transactionID: 0x1F, replyDelayMicroseconds: 59_900)
    add("Razer Viper Ultimate", [0x007A, 0x007B], transactionID: 0xFF, replyDelayMicroseconds: 59_900)
    add("Razer Basilisk X HyperSpeed", [0x0083], transactionID: 0xFF)
    add("Razer Mamba Wireless (2015)", [0x0045], transactionID: 0xFF)
    return models
  }()
}
