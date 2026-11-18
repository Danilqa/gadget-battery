import BatteryKit
import SwiftUI
import WidgetKit

struct BatteryWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let snapshot: Snapshot

  var body: some View {
    if snapshot.peripherals.isEmpty {
      VStack(spacing: 6) {
        Image(systemName: "minus.plus.batteryblock")
          .font(.title2)
          .foregroundStyle(.secondary)
        Text("No devices")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    } else {
      switch family {
      case .systemSmall:
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
          ForEach(Array(rings.splitIntoChunks(of: 2).enumerated()), id: \.offset) { _, row in
            GridRow {
              ForEach(row) { BatteryRing(peripheral: $0, threshold: snapshot.threshold) }
            }
          }
        }
      default:
        VStack(alignment: .leading, spacing: family == .systemLarge ? 10 : 6) {
          ForEach(snapshot.peripherals.prefix(family == .systemLarge ? 8 : 4)) { peripheral in
            BatteryListRow(peripheral: peripheral, threshold: snapshot.threshold)
          }
          Spacer(minLength: 0)
        }
      }
    }
  }

  private var rings: [Peripheral] {
    Array(snapshot.peripherals.sorted { ($0.percent ?? 100) < ($1.percent ?? 100) }.prefix(4))
  }
}

struct BatteryRing: View {
  let peripheral: Peripheral
  let threshold: Int

  var body: some View {
    let percent = peripheral.percent ?? 0
    VStack(spacing: 3) {
      ZStack {
        Circle().stroke(.quaternary, lineWidth: 4)
        Circle()
          .trim(from: 0, to: CGFloat(percent) / 100)
          .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
          .rotationEffect(.degrees(-90))
        Image(systemName: peripheral.kind.symbolName)
          .font(.system(size: 14, weight: .medium))
      }
      .frame(width: 44, height: 44)
      Text("\(percent)%")
        .font(.caption2.weight(.semibold))
        .monospacedDigit()
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(peripheral.name) \(percent)%")
  }

  private var tint: Color {
    peripheral.isCharging ? .green : peripheral.computeChargeLevel(threshold: threshold).color
  }
}

struct BatteryListRow: View {
  let peripheral: Peripheral
  let threshold: Int

  var body: some View {
    let percent = peripheral.percent ?? 0
    HStack(spacing: 8) {
      Image(systemName: peripheral.kind.symbolName)
        .font(.system(size: 13, weight: .medium))
        .frame(width: 20)
        .foregroundStyle(.secondary)
      Text(peripheral.name)
        .font(.subheadline)
        .lineLimit(1)
      Spacer(minLength: 4)
      if peripheral.isCharging {
        Image(systemName: "bolt.fill")
          .font(.caption2)
          .foregroundStyle(.green)
      }
      Text("\(percent)%")
        .font(.subheadline.weight(.semibold))
        .monospacedDigit()
      Gauge(value: Double(percent), in: 0...100) { EmptyView() }
        .gaugeStyle(.linearCapacity)
        .tint(tint)
        .frame(width: 44)
    }
  }

  private var tint: Color {
    peripheral.isCharging ? .green : peripheral.computeChargeLevel(threshold: threshold).color
  }
}

extension Array {
  func splitIntoChunks(of size: Int) -> [[Element]] {
    stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
  }
}
