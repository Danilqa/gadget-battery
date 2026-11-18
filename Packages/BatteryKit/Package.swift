// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "BatteryKit",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "BatteryKit", targets: ["BatteryKit"]),
    .library(name: "BatterySources", targets: ["BatterySources"]),
  ],
  targets: [
    .target(name: "BatteryKit"),
    .target(name: "BatterySources", dependencies: ["BatteryKit"]),
    .testTarget(name: "BatteryKitTests", dependencies: ["BatteryKit"]),
  ]
)
