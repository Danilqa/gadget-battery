import Foundation

public struct LowBatteryPolicy: Sendable {
  public enum Severity: Int, Comparable, Sendable {
    case low = 1, critical = 2

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
  }

  public struct Alert: Equatable, Sendable {
    public var peripheral: Peripheral
    public var severity: Severity
  }

  public static let rearmMargin = 5

  public var threshold: Int
  public var criticalThreshold: Int { max(threshold / 2, 5) }
  private var warned: [String: Severity] = [:]

  public init(threshold: Int) {
    self.threshold = threshold
  }

  public mutating func evaluate(_ peripherals: [Peripheral]) -> [Alert] {
    peripherals.compactMap { peripheral in
      guard let percent = peripheral.percent else { return nil }
      if peripheral.isCharging || percent > threshold + Self.rearmMargin {
        warned[peripheral.id] = nil
        return nil
      }
      let severity: Severity
      if percent <= criticalThreshold {
        severity = .critical
      } else if percent <= threshold {
        severity = .low
      } else {
        return nil
      }
      if let previous = warned[peripheral.id], previous >= severity { return nil }
      warned[peripheral.id] = severity
      return Alert(peripheral: peripheral, severity: severity)
    }
  }
}
