import BatteryKit
import SwiftUI

struct PeripheralRow: View {
  let peripheral: Peripheral
  let threshold: Int

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: peripheral.kind.symbolName)
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 32, height: 32)
        .background(.quaternary, in: .circle)

      VStack(alignment: .leading, spacing: 2) {
        Text(peripheral.name)
          .font(.body)
          .lineLimit(1)
          .truncationMode(.tail)
        if let detail {
          Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .lineLimit(1)
        }
      }

      Spacer(minLength: 8)

      if let percent = peripheral.percent {
        HStack(spacing: 6) {
          Text("\(percent)%")
            .font(.body.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(peripheral.computeChargeLevel(threshold: threshold) == .good ? .primary : tint)
          BatteryBar(percent: percent, isCharging: peripheral.isCharging, tint: tint)
        }
      }
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
  }

  private var tint: Color {
    peripheral.isCharging ? .green : peripheral.computeChargeLevel(threshold: threshold).color
  }

  private var detail: String? {
    let parts = peripheral.cells.compactMap { cell in
      cell.part.shortLabel.map { "\($0) \(cell.percent)%" }
    }
    if !parts.isEmpty {
      return parts.joined(separator: " · ")
    }
    return peripheral.isCharging ? String(localized: "Charging") : nil
  }
}

struct BatteryBar: View {
  let percent: Int
  let isCharging: Bool
  let tint: Color

  var body: some View {
    ZStack(alignment: .leading) {
      Capsule().fill(.quaternary)
      Capsule()
        .fill(tint)
        .frame(width: max(3, 26 * CGFloat(percent) / 100))
      if isCharging {
        Image(systemName: "bolt.fill")
          .font(.system(size: 8, weight: .bold))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
      }
    }
    .frame(width: 26, height: 11)
    .accessibilityHidden(true)
  }
}
