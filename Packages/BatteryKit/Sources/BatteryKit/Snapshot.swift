import Foundation

public struct Snapshot: Codable, Equatable, Sendable {
  public var peripherals: [Peripheral]
  public var threshold: Int
  public var updatedAt: Date

  public init(peripherals: [Peripheral], threshold: Int, updatedAt: Date) {
    self.peripherals = peripherals
    self.threshold = threshold
    self.updatedAt = updatedAt
  }
}

extension Snapshot {
  public static let sample = Snapshot(
    peripherals: [
      Peripheral(id: "sample:mouse", name: "MX Master 3S", kind: .mouse, source: .logitech, cells: [.init(percent: 64)]),
      Peripheral(id: "sample:airpods", name: "AirPods Pro", kind: .earbuds, source: .bluetooth, cells: [
        .init(part: .left, percent: 80), .init(part: .right, percent: 76), .init(part: .case, percent: 45),
      ]),
      Peripheral(id: "sample:controller", name: "DualSense Wireless Controller", kind: .controller, source: .gameController, cells: [.init(percent: 18)]),
      Peripheral(id: "sample:keyboard", name: "Magic Keyboard", kind: .keyboard, source: .appleHID, cells: [.init(percent: 92, isCharging: true)]),
      Peripheral(id: "sample:razer", name: "Razer Viper V3 Pro", kind: .mouse, source: .razer, cells: [.init(percent: 7)]),
    ],
    threshold: 20,
    updatedAt: .now
  )
}

public struct SnapshotStore: Sendable {
  public let fileURL: URL?

  public init(appGroup: String) {
    fileURL = FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
      .appending(path: "snapshot.json")
  }

  public init(fileURL: URL) {
    self.fileURL = fileURL
  }

  public func load() -> Snapshot? {
    guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
    return try? Self.decoder.decode(Snapshot.self, from: data)
  }

  public func save(_ snapshot: Snapshot) throws {
    guard let fileURL else { return }
    try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Self.encoder.encode(snapshot).write(to: fileURL, options: .atomic)
  }

  private static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()

  private static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()
}
