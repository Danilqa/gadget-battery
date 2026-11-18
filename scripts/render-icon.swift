// Renders the app icon PNGs: swift scripts/render-icon.swift App/Assets.xcassets/AppIcon.appiconset
import AppKit

let output = URL(filePath: CommandLine.arguments[1])

func makeColor(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
  CGColor(red: red, green: green, blue: blue, alpha: alpha)
}

func strokeArc(_ context: CGContext, center: CGPoint, radius: CGFloat, width: CGFloat, from start: CGFloat, to end: CGFloat) -> CGPath {
  let path = CGMutablePath()
  path.addArc(center: center, radius: radius, startAngle: start * .pi / 180, endAngle: end * .pi / 180, clockwise: true)
  return path.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 1)
}

func renderIcon(pixels: Int) -> Data {
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
  )!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  let context = NSGraphicsContext.current!.cgContext
  let unit = CGFloat(pixels) / 1024
  context.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))

  // macOS icon grid: 824 pt body centered on a 1024 canvas.
  let body = CGRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit)
  let bodyPath = CGPath(roundedRect: body, cornerWidth: 185 * unit, cornerHeight: 185 * unit, transform: nil)
  context.saveGState()
  context.setShadow(offset: CGSize(width: 0, height: -12 * unit), blur: 28 * unit, color: makeColor(0, 0, 0, 0.4))
  context.addPath(bodyPath)
  context.setFillColor(makeColor(0.02, 0.02, 0.03))
  context.fillPath()
  context.restoreGState()

  context.saveGState()
  context.addPath(bodyPath)
  context.clip()
  let background = CGGradient(colorsSpace: nil, colors: [makeColor(0.11, 0.12, 0.14), makeColor(0.02, 0.02, 0.03)] as CFArray, locations: [0, 1])!
  context.drawLinearGradient(background, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])
  let sheenCenter = CGPoint(x: 512 * unit, y: 980 * unit)
  let sheen = CGGradient(colorsSpace: nil, colors: [makeColor(1, 1, 1, 0.10), makeColor(1, 1, 1, 0)] as CFArray, locations: [0, 1])!
  context.drawRadialGradient(sheen, startCenter: sheenCenter, startRadius: 0, endCenter: sheenCenter, endRadius: 620 * unit, options: [])
  context.restoreGState()
  context.addPath(bodyPath)
  context.setStrokeColor(makeColor(1, 1, 1, 0.08))
  context.setLineWidth(3 * unit)
  context.strokePath()

  let center = CGPoint(x: 512 * unit, y: 512 * unit)
  context.addPath(strokeArc(context, center: center, radius: 268 * unit, width: 64 * unit, from: 0, to: -360))
  context.setFillColor(makeColor(1, 1, 1, 0.08))
  context.fillPath()

  let charge = strokeArc(context, center: center, radius: 268 * unit, width: 64 * unit, from: 90, to: 90 - 280)
  context.saveGState()
  context.setShadow(offset: .zero, blur: 70 * unit, color: makeColor(0.3, 1, 0.5, 0.55))
  context.addPath(charge)
  context.setFillColor(makeColor(0.25, 0.9, 0.48))
  context.fillPath()
  context.restoreGState()
  context.saveGState()
  context.addPath(charge)
  context.clip()
  let ring = CGGradient(colorsSpace: nil, colors: [makeColor(0.68, 0.96, 0.36), makeColor(0.25, 0.9, 0.48)] as CFArray, locations: [0, 1])!
  context.drawLinearGradient(ring, start: CGPoint(x: 244 * unit, y: 780 * unit), end: CGPoint(x: 780 * unit, y: 244 * unit), options: [])
  context.restoreGState()

  let symbol = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: nil)!
    .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 240 * unit, weight: .semibold).applying(.init(paletteColors: [.white])))!
  let scale = min(200 * unit / symbol.size.width, 240 * unit / symbol.size.height)
  let size = CGSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
  symbol.draw(in: CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height))

  NSGraphicsContext.restoreGraphicsState()
  return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let file = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
    try renderIcon(pixels: points * scale).write(to: output.appending(path: file))
    images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": file])
  }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
  .write(to: output.appending(path: "Contents.json"))
