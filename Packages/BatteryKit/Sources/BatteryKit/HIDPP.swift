import Foundation

// Byte layouts follow Solaar's logitech_receiver package.
public enum HIDPP {
  public static let vendorID = 0x046D
  public static let shortReportID: UInt8 = 0x10
  public static let longReportID: UInt8 = 0x11
  public static let shortReportLength = 7
  public static let longReportLength = 20
  // Solaar, G HUB and the Linux driver use 0x0B, 0x0D and 0x01.
  public static let softwareID: UInt8 = 0x0E
  public static let directDeviceIndex: UInt8 = 0xFF

  public enum Feature: UInt16, Sendable {
    case root = 0x0000
    case deviceName = 0x0005
    case batteryStatus = 0x1000
    case batteryVoltage = 0x1001
    case unifiedBattery = 0x1004
    case headsetVoltage = 0x1F20
  }

  public struct Request: Equatable, Sendable {
    public var deviceIndex: UInt8
    public var featureIndex: UInt8
    public var function: UInt8
    public var parameters: [UInt8]

    public init(deviceIndex: UInt8, featureIndex: UInt8, function: UInt8, parameters: [UInt8] = []) {
      self.deviceIndex = deviceIndex
      self.featureIndex = featureIndex
      self.function = function
      self.parameters = parameters
    }

    var functionAndSoftwareID: UInt8 { (function << 4) | HIDPP.softwareID }

    public func encode(isLongReport: Bool) -> [UInt8] {
      let length = isLongReport ? HIDPP.longReportLength : HIDPP.shortReportLength
      var bytes = [isLongReport ? HIDPP.longReportID : HIDPP.shortReportID, deviceIndex, featureIndex, functionAndSoftwareID]
      bytes += parameters.prefix(length - bytes.count)
      bytes += [UInt8](repeating: 0, count: length - bytes.count)
      return bytes
    }
  }

  public enum Reply: Equatable, Sendable {
    case success(parameters: [UInt8])
    case failure(code: UInt8, isLegacy: Bool)
  }

  public enum ErrorCode {
    public static let legacyInvalidSubID: UInt8 = 0x01
    public static let legacyConnectFailed: UInt8 = 0x04
    public static let legacyUnknownDevice: UInt8 = 0x08
    public static let legacyResourceError: UInt8 = 0x09
  }

  public static func decodeReply(_ report: [UInt8], to request: Request) -> Reply? {
    guard report.count >= shortReportLength,
      report[0] == shortReportID || report[0] == longReportID,
      // Bluetooth devices may answer a 0xFF request on index 0x00.
      report[1] == request.deviceIndex || report[1] == request.deviceIndex ^ 0xFF
    else { return nil }

    if report[2] == 0xFF, report[3] == request.featureIndex, report[4] == request.functionAndSoftwareID {
      return .failure(code: report[5], isLegacy: false)
    }
    if report[2] == 0x8F, report[3] == request.featureIndex, report[4] == request.functionAndSoftwareID {
      return .failure(code: report[5], isLegacy: true)
    }
    guard report[2] == request.featureIndex, report[3] == request.functionAndSoftwareID else { return nil }
    return .success(parameters: Array(report[4...]))
  }

  public struct BatteryReading: Equatable, Sendable {
    public var percent: Int
    public var isCharging: Bool
  }

  // Status: 1, 2 and 4 are charging, 3 is full, 5 and up are errors.
  public static func parseBatteryStatus(_ parameters: [UInt8]) -> BatteryReading? {
    guard parameters.count >= 3 else { return nil }
    let status = parameters[2]
    let isCharging = [1, 2, 4].contains(status)
    let percent = status == 3 ? 100 : Int(parameters[0])
    guard percent > 0 || isCharging else { return nil }
    return BatteryReading(percent: percent, isCharging: isCharging)
  }

  // Charging status: 1 and 2 are charging, 3 is complete, 4 is an error.
  public static func parseUnifiedBattery(_ parameters: [UInt8]) -> BatteryReading? {
    guard parameters.count >= 3 else { return nil }
    let charging = parameters[2]
    var percent = Int(parameters[0])
    if percent == 0 {
      // Devices without a fuel gauge only report a coarse level.
      let level = parameters[1]
      percent = level & 0x08 != 0 ? 100 : level & 0x04 != 0 ? 60 : level & 0x02 != 0 ? 20 : level & 0x01 != 0 ? 5 : 0
    }
    let isCharging = charging == 1 || charging == 2
    if charging == 3 { percent = 100 }
    guard percent > 0 else { return nil }
    return BatteryReading(percent: percent, isCharging: isCharging)
  }

  // Flags: bit 7 is external power, then the low bits are 0 charging, 1 full, 2 not charging.
  public static func parseBatteryVoltage(_ parameters: [UInt8]) -> BatteryReading? {
    guard parameters.count >= 3 else { return nil }
    let millivolts = Int(parameters[0]) << 8 | Int(parameters[1])
    guard millivolts > 0 else { return nil }
    let flags = parameters[2]
    let hasPower = flags & 0x80 != 0
    let isFull = hasPower && flags & 0x07 == 1
    let isCharging = hasPower && flags & 0x07 == 0
    return BatteryReading(percent: isFull ? 100 : estimatePercent(millivolts: millivolts), isCharging: isCharging)
  }

  public static func parseHeadsetVoltage(_ parameters: [UInt8]) -> BatteryReading? {
    guard parameters.count >= 3 else { return nil }
    let millivolts = Int(parameters[0]) << 8 | Int(parameters[1])
    guard millivolts > 0 else { return nil }
    return BatteryReading(percent: estimatePercent(millivolts: millivolts), isCharging: parameters[2] & 0x02 != 0)
  }

  public static func convertDeviceType(_ type: UInt8) -> Peripheral.Kind? {
    switch type {
    case 0, 2: .keyboard
    case 3, 5: .mouse
    case 4: .trackpad
    case 8: .headset
    case 12: .controller
    default: nil
    }
  }

  // Solaar's discharge curve for Logitech's Li-ion cells.
  static let voltageCurve: [(millivolts: Int, percent: Int)] = [
    (4186, 100), (4067, 90), (3989, 80), (3922, 70), (3859, 60), (3811, 50),
    (3778, 40), (3751, 30), (3717, 20), (3671, 10), (3646, 5), (3579, 2), (3500, 0),
  ]

  public static func estimatePercent(millivolts: Int) -> Int {
    guard let first = voltageCurve.first, millivolts < first.millivolts else { return 100 }
    for (upper, lower) in zip(voltageCurve, voltageCurve.dropFirst()) where millivolts >= lower.millivolts {
      let span = Double(upper.millivolts - lower.millivolts)
      let fraction = Double(millivolts - lower.millivolts) / span
      return lower.percent + Int((fraction * Double(upper.percent - lower.percent)).rounded())
    }
    return 0
  }
}
