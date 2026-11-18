import Foundation
import IOKit.hid

@MainActor
final class HIDDeviceHub {
  var onAttach: ((HIDInterface) -> Void)?
  var onDetach: ((HIDInterface) -> Void)?
  private(set) var interfaces: [HIDInterface] = []

  private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
  private let matching: [[String: Int]]
  private var isStarted = false

  init(matching: [[String: Int]]) {
    self.matching = matching
  }

  func start() {
    guard !isStarted else { return }
    isStarted = true
    IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)
    let context = Unmanaged.passUnretained(self).toOpaque()
    IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
      guard let context else { return }
      let hub = Unmanaged<HIDDeviceHub>.fromOpaque(context).takeUnretainedValue()
      MainActor.assumeIsolated { hub.attach(device) }
    }, context)
    IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
      guard let context else { return }
      let hub = Unmanaged<HIDDeviceHub>.fromOpaque(context).takeUnretainedValue()
      MainActor.assumeIsolated { hub.detach(device) }
    }, context)
    // Opening the manager opens every match and can raise the Input Monitoring prompt.
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
  }

  private func attach(_ device: IOHIDDevice) {
    guard !interfaces.contains(where: { $0.device == device }) else { return }
    let interface = HIDInterface(device: device)
    interfaces.append(interface)
    onAttach?(interface)
  }

  private func detach(_ device: IOHIDDevice) {
    guard let index = interfaces.firstIndex(where: { $0.device == device }) else { return }
    let interface = interfaces.remove(at: index)
    interface.close()
    onDetach?(interface)
  }
}

@MainActor
final class HIDInterface {
  let device: IOHIDDevice
  var onInputReport: ((Data) -> Void)?
  private var buffer: UnsafeMutablePointer<UInt8>?
  private var isOpen = false

  init(device: IOHIDDevice) {
    self.device = device
  }

  var vendorID: Int { readIntProperty(kIOHIDVendorIDKey) ?? 0 }
  var productID: Int { readIntProperty(kIOHIDProductIDKey) ?? 0 }
  var usagePage: Int { readIntProperty(kIOHIDPrimaryUsagePageKey) ?? 0 }
  var usage: Int { readIntProperty(kIOHIDPrimaryUsageKey) ?? 0 }
  var locationID: Int { readIntProperty(kIOHIDLocationIDKey) ?? 0 }
  var transport: String { readStringProperty(kIOHIDTransportKey) ?? "" }
  var product: String { readStringProperty(kIOHIDProductKey) ?? "" }
  var serialNumber: String? { readStringProperty(kIOHIDSerialNumberKey) }
  var maxInputReportSize: Int { readIntProperty(kIOHIDMaxInputReportSizeKey) ?? 64 }

  var usagePairs: [(page: Int, usage: Int)] {
    let pairs = IOHIDDeviceGetProperty(device, kIOHIDDeviceUsagePairsKey as CFString) as? [[String: Any]] ?? []
    return pairs.compactMap { pair in
      guard let page = (pair[kIOHIDDeviceUsagePageKey] as? NSNumber)?.intValue,
        let usage = (pair[kIOHIDDeviceUsageKey] as? NSNumber)?.intValue
      else { return nil }
      return (page, usage)
    }
  }

  // macOS gates any interface that is also a keyboard, mouse or touchpad.
  func checkNeedsInputMonitoring() -> Bool {
    usagePairs.contains { pair in
      (pair.page == 0x01 && (pair.usage == 0x02 || pair.usage == 0x06)) || (pair.page == 0x0D && pair.usage == 0x05)
    }
  }

  func openIfAllowed() -> Bool {
    guard !checkNeedsInputMonitoring() || InputMonitoring.checkIsGranted() else { return false }
    return open()
  }

  // Not seized, so the system keeps receiving the device's input.
  func open() -> Bool {
    if isOpen { return true }
    guard IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else { return false }
    isOpen = true
    let size = max(maxInputReportSize, 64)
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
    self.buffer = buffer
    let context = Unmanaged.passUnretained(self).toOpaque()
    IOHIDDeviceRegisterInputReportCallback(device, buffer, size, { context, _, _, _, reportID, report, length in
      guard let context else { return }
      let interface = Unmanaged<HIDInterface>.fromOpaque(context).takeUnretainedValue()
      let data = Data(bytes: report, count: length)
      MainActor.assumeIsolated { interface.onInputReport?(data) }
    }, context)
    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    return true
  }

  func close() {
    guard isOpen, let buffer else { return }
    isOpen = false
    IOHIDDeviceRegisterInputReportCallback(device, buffer, max(maxInputReportSize, 64), nil, nil)
    IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
    buffer.deallocate()
    self.buffer = nil
  }

  // `report` starts with the report ID byte.
  @discardableResult
  func sendOutputReport(_ report: [UInt8]) -> Bool {
    guard let reportID = report.first else { return false }
    return report.withUnsafeBufferPointer { bytes in
      bytes.baseAddress.map {
        IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(reportID), $0, bytes.count)
      }
    } == kIOReturnSuccess
  }

  func sendFeatureReport(_ report: [UInt8], reportID: Int) -> Bool {
    report.withUnsafeBufferPointer { bytes in
      bytes.baseAddress.map {
        IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, CFIndex(reportID), $0, bytes.count)
      }
    } == kIOReturnSuccess
  }

  func readFeatureReport(length: Int, reportID: Int) -> [UInt8]? {
    guard length > 0 else { return nil }
    var report = [UInt8](repeating: 0, count: length)
    var size = CFIndex(length)
    let result = report.withUnsafeMutableBufferPointer { bytes in
      IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, CFIndex(reportID), bytes.baseAddress!, &size)
    }
    guard result == kIOReturnSuccess else { return nil }
    return Array(report.prefix(size))
  }

  private func readIntProperty(_ key: String) -> Int? {
    (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue
  }

  private func readStringProperty(_ key: String) -> String? {
    IOHIDDeviceGetProperty(device, key as CFString) as? String
  }
}

public enum InputMonitoring {
  public static func checkIsGranted() -> Bool {
    IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
  }

  // Prompts only once; after that the switch is in System Settings.
  @discardableResult
  public static func request() -> Bool {
    IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
  }
}
