import BatteryKit
import SwiftUI

struct SettingsView: View {
  @Environment(BatteryMonitor.self) private var monitor
  @Environment(Preferences.self) private var preferences

  var body: some View {
    @Bindable var preferences = preferences
    Form {
      Section {
        Toggle("Open at login", isOn: $preferences.isLaunchedAtLogin)
        Toggle("Show the lowest level in the menu bar", isOn: $preferences.isPercentInMenuBar)
      }

      Section("Low battery") {
        Toggle("Warn me before a device dies", isOn: $preferences.areNotificationsEnabled)
        LabeledContent("Warn at") {
          HStack {
            Slider(
              value: Binding(
                get: { Double(preferences.threshold) },
                set: { preferences.threshold = Int($0) }
              ),
              in: Double(Preferences.thresholdRange.lowerBound)...Double(Preferences.thresholdRange.upperBound),
              step: 5
            )
            Text("\(preferences.threshold)%")
              .monospacedDigit()
              .frame(width: 40, alignment: .trailing)
          }
        }
        .disabled(!preferences.areNotificationsEnabled)
      }

      Section {
        if knownPeripherals.isEmpty {
          Text("Devices appear here once they report a battery level.")
            .foregroundStyle(.secondary)
        }
        ForEach(knownPeripherals) { peripheral in
          Toggle(isOn: makeVisibilityBinding(for: peripheral)) {
            Label(peripheral.name, systemImage: peripheral.kind.symbolName)
          }
        }
      } header: {
        Text("Devices")
      } footer: {
        Text("Hidden devices stay out of the menu bar, the widget and the warnings.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .onChange(of: preferences.threshold) { monitor.applyThreshold() }
    .frame(width: 440)
    .fixedSize(horizontal: false, vertical: true)
  }

  private var knownPeripherals: [Peripheral] {
    monitor.peripherals
  }

  private func makeVisibilityBinding(for peripheral: Peripheral) -> Binding<Bool> {
    Binding(
      get: { !preferences.hiddenIDs.contains(peripheral.id) },
      set: { isVisible in
        if isVisible {
          preferences.hiddenIDs.remove(peripheral.id)
        } else {
          preferences.hiddenIDs.insert(peripheral.id)
        }
        monitor.publishSnapshot()
      }
    )
  }
}
