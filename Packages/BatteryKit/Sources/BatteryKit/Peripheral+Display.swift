import Foundation
import SwiftUI

extension Peripheral.Kind {
  public var symbolName: String {
    switch self {
    case .mouse: "computermouse.fill"
    case .keyboard: "keyboard.fill"
    case .trackpad: "rectangle.and.hand.point.up.left.fill"
    case .earbuds: "airpodspro"
    case .headphones: "headphones"
    case .headset: "headphones"
    case .controller: "gamecontroller.fill"
    case .speaker: "hifispeaker.fill"
    case .pen: "applepencil"
    case .other: "dot.radiowaves.left.and.right"
    }
  }
}

extension Peripheral.Cell.Part {
  public var shortLabel: String? {
    switch self {
    case .main: nil
    case .left: String(localized: "L")
    case .right: String(localized: "R")
    case .case: String(localized: "Case")
    }
  }
}

public enum ChargeLevel: Sendable {
  case good, low, critical

  public init(percent: Int, threshold: Int) {
    let policy = LowBatteryPolicy(threshold: threshold)
    self = if percent <= policy.criticalThreshold { .critical } else if percent <= threshold { .low } else { .good }
  }
}

extension ChargeLevel {
  public var color: Color {
    switch self {
    case .good: .green
    case .low: .orange
    case .critical: .red
    }
  }
}

extension Peripheral {
  public func computeChargeLevel(threshold: Int) -> ChargeLevel {
    ChargeLevel(percent: percent ?? 100, threshold: threshold)
  }
}
