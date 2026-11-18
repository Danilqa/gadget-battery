import BatteryKit
import Foundation
import os

public struct BluetoothReportSource: Sendable {
  private static let logger = Logger(subsystem: "BatterySources", category: "BluetoothReport")

  public init() {}

  @concurrent
  public func readPeripherals() async -> [Peripheral] {
    let process = Process()
    process.executableURL = URL(filePath: "/usr/sbin/system_profiler")
    process.arguments = ["SPBluetoothDataType", "-json", "-detailLevel", "basic"]
    let output = Pipe()
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
      let data = try output.fileHandleForReading.readToEnd() ?? Data()
      process.waitUntilExit()
      return try BluetoothReportParser.parsePeripherals(from: data)
    } catch {
      Self.logger.error("system_profiler failed: \(error.localizedDescription, privacy: .public)")
      return []
    }
  }
}
