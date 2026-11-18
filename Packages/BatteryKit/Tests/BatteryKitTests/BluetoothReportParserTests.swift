import Foundation
import Testing

@testable import BatteryKit

struct BluetoothReportParserTests {
  private let report = """
    {
      "SPBluetoothDataType" : [
        {
          "controller_properties" : { "controller_address" : "84:2F:57:91:0F:90" },
          "device_connected" : [
            {
              "Daniil’s AirPods Pro" : {
                "device_address" : "50:F3:51:E6:43:84",
                "device_batteryLevelCase" : "45%",
                "device_batteryLevelLeft" : "80%",
                "device_batteryLevelRight" : "75%",
                "device_minorType" : "Headphones",
                "device_vendorID" : "0x004C"
              }
            },
            {
              "Magic Mouse" : {
                "device_address" : "04:4B:ED:01:02:03",
                "device_batteryLevelMain" : "12%",
                "device_minorType" : "Mouse"
              }
            },
            {
              "Daniil Sitdikov’s iPad" : { "device_address" : "4C:2E:B4:71:11:8D" }
            }
          ],
          "device_not_connected" : [
            {
              "Old Keyboard" : { "device_address" : "48:E1:5C:BD:62:BB", "device_batteryLevelMain" : "99%" }
            }
          ]
        }
      ]
    }
    """

  @Test func `reads connected devices that report a battery`() throws {
    let peripherals = try BluetoothReportParser.parsePeripherals(from: Data(report.utf8))

    #expect(peripherals.map(\.name).sorted() == ["Daniil’s AirPods Pro", "Magic Mouse"])
  }

  @Test func `splits AirPods into buds and case and ignores the case for the level`() throws {
    let peripherals = try BluetoothReportParser.parsePeripherals(from: Data(report.utf8))
    let airPods = try #require(peripherals.first { $0.name == "Daniil’s AirPods Pro" })

    #expect(airPods.kind == .earbuds)
    #expect(airPods.cells.map(\.part) == [.left, .right, .case])
    #expect(airPods.percent == 75)
    #expect(airPods.address == "50f351e64384")
  }

  @Test func `reads a single main level`() throws {
    let peripherals = try BluetoothReportParser.parsePeripherals(from: Data(report.utf8))
    let mouse = try #require(peripherals.first { $0.name == "Magic Mouse" })

    #expect(mouse.kind == .mouse)
    #expect(mouse.percent == 12)
  }

  @Test(arguments: [("85%", 85), (" 7 %", 7), ("n/a", nil)] as [(String, Int?)])
  func `parses percent strings`(text: String, expected: Int?) {
    #expect(BluetoothReportParser.parsePercent(text) == expected)
  }

  @Test func `returns nothing for an empty report`() throws {
    #expect(try BluetoothReportParser.parsePeripherals(from: Data("{}".utf8)).isEmpty)
  }
}
