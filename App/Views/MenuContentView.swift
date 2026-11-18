import BatteryKit
import SwiftUI

struct MenuContentView: View {
  @Environment(BatteryMonitor.self) private var monitor
  @Environment(Preferences.self) private var preferences
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      Divider().padding(.horizontal, 12)
      if monitor.visiblePeripherals.isEmpty {
        emptyState
      } else {
        VStack(spacing: 2) {
          ForEach(monitor.visiblePeripherals) { peripheral in
            PeripheralRow(peripheral: peripheral, threshold: preferences.threshold)
              .contextMenu {
                Button("Hide “\(peripheral.name)”") {
                  preferences.hiddenIDs.insert(peripheral.id)
                  monitor.publishSnapshot()
                }
              }
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
      }
      if !monitor.blockedProducts.isEmpty {
        accessPrompt
      }
      Divider().padding(.horizontal, 12)
      footer
    }
    .frame(width: 320)
    .task { await monitor.refresh() }
  }

  private var header: some View {
    HStack {
      Text("Devices")
        .font(.headline)
      Spacer()
      Button {
        Task { await monitor.refresh() }
      } label: {
        Image(systemName: "arrow.clockwise")
      }
      .buttonStyle(.borderless)
      .disabled(monitor.isRefreshing)
      .help("Refresh")
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
  }

  private var emptyState: some View {
    VStack(spacing: 6) {
      Image(systemName: "minus.plus.batteryblock")
        .font(.system(size: 28))
        .foregroundStyle(.secondary)
      Text("No wireless devices yet")
        .font(.headline)
      Text("Turn on a Bluetooth mouse, keyboard, headphones or controller, or plug in a Logitech or Razer receiver.")
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 20)
    .padding(.vertical, 24)
  }

  private var accessPrompt: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("\(monitor.blockedProducts.formatted(.list(type: .and))) found")
        .font(.callout.weight(.medium))
      Text("macOS asks for Input Monitoring before an app can read this receiver. Gadget Battery only reads the battery level.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Button("Allow Access…") { monitor.requestInputMonitoring() }
        .controlSize(.small)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
  }

  private var footer: some View {
    HStack {
      if let updatedAt = monitor.updatedAt {
        Text("Updated \(updatedAt, format: .relative(presentation: .named))")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button("Settings…") {
        NSApp.activate()
        openSettings()
      }
      .keyboardShortcut(",")
      Button("Quit") { NSApp.terminate(nil) }
        .keyboardShortcut("q")
    }
    .buttonStyle(.borderless)
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
  }
}
