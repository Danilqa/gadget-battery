import Foundation

public struct Peripheral: Codable, Hashable, Identifiable, Sendable {
  public enum Kind: String, Codable, Sendable, CaseIterable {
    case mouse, keyboard, trackpad, earbuds, headphones, headset, controller, speaker, pen, other
  }

  public enum Source: String, Codable, Sendable {
    case appleHID, bluetooth, gameController, bluetoothLE, logitech, razer
  }

  public struct Cell: Codable, Hashable, Sendable {
    public enum Part: String, Codable, Sendable {
      case main, left, right, `case`
    }

    public var part: Part
    public var percent: Int
    public var isCharging: Bool

    public init(part: Part = .main, percent: Int, isCharging: Bool = false) {
      self.part = part
      self.percent = min(max(percent, 0), 100)
      self.isCharging = isCharging
    }
  }

  public var id: String
  public var name: String
  public var kind: Kind
  public var source: Source
  public var cells: [Cell]
  public var address: String?

  public init(id: String, name: String, kind: Kind, source: Source, cells: [Cell], address: String? = nil) {
    self.id = id
    self.name = name
    self.kind = kind
    self.source = source
    self.cells = cells
    self.address = address.map(Self.normalizeAddress)
  }

  // The charging case doesn't decide when the buds die.
  public var primaryCell: Cell? {
    let wearable = cells.filter { $0.part != .case }
    return (wearable.isEmpty ? cells : wearable).min { $0.percent < $1.percent }
  }

  public var percent: Int? { primaryCell?.percent }

  public var isCharging: Bool { primaryCell?.isCharging ?? false }

  public var mergeKey: String { address ?? Self.normalizeName(name) }

  public static func normalizeAddress(_ address: String) -> String {
    address.lowercased().filter(\.isHexDigit)
  }

  static func normalizeName(_ name: String) -> String {
    name.lowercased().filter { $0.isLetter || $0.isNumber }
  }

  public static func guessKind(fromName name: String) -> Kind {
    let lowered = name.lowercased()
    let rules: [(Kind, [String])] = [
      (.trackpad, ["trackpad", "touchpad"]),
      (.mouse, ["mouse", "mx master", "mx anywhere", "viper", "deathadder", "basilisk", "g pro", "g502", "g305", "g703", "g903", "superlight", "naga", "orochi", "pro click", "cobra"]),
      (.keyboard, ["keyboard", "keys", "mx mechanical", "craft", "k380", "k780", "g915"]),
      (.controller, ["controller", "gamepad", "dualsense", "dualshock", "joy-con", "8bitdo"]),
      (.earbuds, ["airpods", "buds", "powerbeats", "beats fit", "beats flex", "studio buds"]),
      (.headset, ["headset", "blackshark", "barracuda", "kraken", "arctis", "astro", "g733", "g935", "hyperx"]),
      (.headphones, ["headphones", "beats", "wh-1000", "bose", "sennheiser", "momentum", "airpods max"]),
      (.speaker, ["speaker", "soundlink", "boom", "jbl"]),
      (.pen, ["pencil", "stylus"]),
    ]
    if lowered.contains("airpods max") { return .headphones }
    return rules.first { _, needles in needles.contains { lowered.contains($0) } }?.0 ?? .other
  }
}
