#if DEBUG
import AppKit
import SwiftUI

// Renders the README picture offscreen: `--args -demo YES -snapshotPanel <path.png>`.
enum PanelSnapshot {
  static func writeIfRequested(monitor: BatteryMonitor, preferences: Preferences) {
    guard let path = UserDefaults.standard.string(forKey: "snapshotPanel") else { return }
    Task {
      try? await Task.sleep(for: .milliseconds(500))
      let view = PanelSnapshotView()
        .environment(monitor)
        .environment(preferences)
        .environment(\.colorScheme, .dark)
      let hostingView = NSHostingView(rootView: view)
      hostingView.appearance = NSAppearance(named: .darkAqua)
      hostingView.frame = NSRect(origin: .zero, size: hostingView.fittingSize)
      let window = NSWindow(contentRect: hostingView.frame, styleMask: .borderless, backing: .buffered, defer: false)
      window.contentView = hostingView
      hostingView.layoutSubtreeIfNeeded()
      if let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) {
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(filePath: path))
      }
      exit(0)
    }
  }
}

private struct PanelSnapshotView: View {
  var body: some View {
    VStack(alignment: .trailing, spacing: 8) {
      HStack(spacing: 14) {
        MenuBarLabel()
          .padding(.horizontal, 8)
          .padding(.vertical, 2)
          .background(.white.opacity(0.18), in: .rect(cornerRadius: 5))
        Image(systemName: "wifi")
        Image(systemName: "battery.75percent")
        Text("Wed 18 Nov 9:41")
      }
      .font(.system(size: 13, weight: .medium))
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity, alignment: .trailing)
      .padding(.horizontal, 16)
      .frame(height: 26)
      .background(.black.opacity(0.35))

      MenuContentView()
        .background(Color(nsColor: .windowBackgroundColor), in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
        .padding(.leading, 120)
        .padding(.trailing, 60)
        .padding(.bottom, 40)
    }
    .frame(width: 520)
    .background(
      LinearGradient(
        colors: [Color(red: 0.16, green: 0.20, blue: 0.30), Color(red: 0.05, green: 0.06, blue: 0.10)],
        startPoint: .top, endPoint: .bottom
      )
    )
  }
}
#endif
