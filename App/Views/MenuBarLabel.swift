import AppKit
import BatteryKit
import SwiftUI

// No battery glyph, so it never reads as the Mac's own battery.
struct MenuBarLabel: View {
  @Environment(BatteryMonitor.self) private var monitor
  @Environment(Preferences.self) private var preferences

  var body: some View {
    if let lowest = monitor.lowestPeripheral, let percent = lowest.percent {
      HStack(spacing: 4) {
        Image(nsImage: Self.makeGlyph(kind: lowest.kind, percent: percent, isCharging: lowest.isCharging))
        if preferences.isPercentInMenuBar {
          Text("\(percent)%").monospacedDigit()
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(lowest.name) \(percent)%")
    } else {
      Image(systemName: "minus.plus.batteryblock")
        .accessibilityLabel("No devices")
    }
  }

  static func makeGlyph(kind: Peripheral.Kind, percent: Int, isCharging: Bool) -> NSImage {
    let ringDiameter: CGFloat = 13
    let lineWidth: CGFloat = 2
    let glyphWidth: CGFloat = 17
    let gap: CGFloat = 4
    let size = NSSize(width: glyphWidth + gap + ringDiameter + lineWidth, height: 18)
    let image = NSImage(size: size, flipped: false) { _ in
      let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
      if let symbol = NSImage(systemSymbolName: kind.symbolName, accessibilityDescription: nil)?
        .withSymbolConfiguration(symbolConfiguration)
      {
        let scale = min(glyphWidth / symbol.size.width, 14 / symbol.size.height, 1)
        let fitted = NSSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
        symbol.draw(in: NSRect(
          x: (glyphWidth - fitted.width) / 2, y: (size.height - fitted.height) / 2,
          width: fitted.width, height: fitted.height
        ))
      }

      let center = NSPoint(x: glyphWidth + gap + (ringDiameter + lineWidth) / 2, y: size.height / 2)
      let radius = ringDiameter / 2
      let track = NSBezierPath()
      track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
      track.lineWidth = lineWidth
      NSColor.black.withAlphaComponent(0.3).setStroke()
      track.stroke()

      let progress = NSBezierPath()
      progress.appendArc(
        withCenter: center, radius: radius, startAngle: 90,
        endAngle: 90 - 360 * CGFloat(max(percent, 3)) / 100, clockwise: true
      )
      progress.lineWidth = lineWidth
      progress.lineCapStyle = .round
      NSColor.black.setStroke()
      progress.stroke()

      if isCharging, let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 6, weight: .bold))
      {
        bolt.draw(in: NSRect(
          x: center.x - bolt.size.width / 2, y: center.y - bolt.size.height / 2,
          width: bolt.size.width, height: bolt.size.height
        ))
      }
      return true
    }
    image.isTemplate = true
    return image
  }
}
