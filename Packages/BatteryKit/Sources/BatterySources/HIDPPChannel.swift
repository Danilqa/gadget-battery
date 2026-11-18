import BatteryKit
import Foundation

@MainActor
final class HIDPPChannel {
  let interface: HIDInterface
  var onNotification: (([UInt8]) -> Void)?
  private var pending: (token: Int, request: HIDPP.Request, continuation: CheckedContinuation<HIDPP.Reply?, Never>)?
  private var nextToken = 0

  init(interface: HIDInterface) {
    self.interface = interface
    interface.onInputReport = { [weak self] data in self?.handle(Array(data)) }
  }

  // Interfaces that only declare the long collection reject short reports.
  private var supportsShortReports: Bool {
    interface.usagePairs.contains { pair in
      (pair.page == 0xFF00 && pair.usage == 0x0001) || (pair.page == 0xFF43 && pair.usage & 0x01 != 0)
    }
  }

  func send(_ request: HIDPP.Request, timeout: Duration) async -> HIDPP.Reply? {
    guard pending == nil else { return nil }
    let isLong = request.parameters.count > 3 || !supportsShortReports
    guard interface.sendOutputReport(request.encode(isLongReport: isLong)) else { return nil }
    nextToken += 1
    let token = nextToken
    return await withCheckedContinuation { continuation in
      pending = (token, request, continuation)
      Task { [weak self] in
        try? await Task.sleep(for: timeout)
        self?.resumePending(token: token, with: nil)
      }
    }
  }

  private func handle(_ report: [UInt8]) {
    if let pending, let reply = HIDPP.decodeReply(report, to: pending.request) {
      resumePending(token: pending.token, with: reply)
    } else if report.count >= 4, report[3] & 0x0F == 0 {
      onNotification?(report)
    }
  }

  private func resumePending(token: Int, with reply: HIDPP.Reply?) {
    guard let pending, pending.token == token else { return }
    self.pending = nil
    pending.continuation.resume(returning: reply)
  }
}
