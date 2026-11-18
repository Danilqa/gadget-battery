import BatteryKit
import SwiftUI
import WidgetKit

struct BatteryEntry: TimelineEntry {
  var date: Date
  var snapshot: Snapshot
}

struct BatteryTimelineProvider: TimelineProvider {
  private let store = SnapshotStore(appGroup: AppGroup.identifier)

  func placeholder(in context: Context) -> BatteryEntry {
    BatteryEntry(date: .now, snapshot: .sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (BatteryEntry) -> Void) {
    let snapshot = context.isPreview ? store.load() ?? .sample : store.load() ?? .empty
    completion(BatteryEntry(date: .now, snapshot: snapshot))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryEntry>) -> Void) {
    let entry = BatteryEntry(date: .now, snapshot: store.load() ?? .empty)
    // The app reloads the widget on every change; this covers the app not running.
    completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60))))
  }
}

struct BatteryWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "BatteryWidget", provider: BatteryTimelineProvider()) { entry in
      BatteryWidgetView(snapshot: entry.snapshot)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    .configurationDisplayName("Device Batteries")
    .description("Battery levels of your mice, keyboards, headphones and controllers.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

@main
struct BatteryWidgetBundle: WidgetBundle {
  var body: some Widget {
    BatteryWidget()
  }
}

extension Snapshot {
  static let empty = Snapshot(peripherals: [], threshold: 20, updatedAt: .now)
}
