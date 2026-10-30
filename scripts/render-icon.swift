import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources")
try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)

let black = CGColor(gray: 0, alpha: 1)
let white = CGColor(gray: 1, alpha: 1)

// Shared face geometry in a 1024 canvas (y-up). Vertically centered so dock,
// circle, and menu-bar share the same optical midline.
let faceEarR: CGFloat = 188
let faceEarY: CGFloat = 723
let faceEarLX: CGFloat = 308
let faceEarRX: CGFloat = 716
let faceHead = CGPoint(x: 512, y: 405)
let faceHeadR: CGFloat = 292
let faceEyeY: CGFloat = 445
let faceEyeLX: CGFloat = 372
let faceEyeRX: CGFloat = 652
let faceEyeArm: CGFloat = 59
let faceEyeWidth: CGFloat = 47

func ellipse(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat) -> CGRect {
    CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2)
}

func strokeXs(in ctx: CGContext, left: CGPoint, right: CGPoint, arm: CGFloat, width: CGFloat) {
    ctx.setBlendMode(.destinationOut)
    ctx.setStrokeColor(black)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    for c in [left, right] {
        ctx.move(to: CGPoint(x: c.x - arm, y: c.y - arm))
        ctx.addLine(to: CGPoint(x: c.x + arm, y: c.y + arm))
        ctx.move(to: CGPoint(x: c.x - arm, y: c.y + arm))
        ctx.addLine(to: CGPoint(x: c.x + arm, y: c.y - arm))
    }
    ctx.strokePath()
}

// Menu-bar template, 18×18 pt, y-up. Opaque pixels are the only thing the bar tints.
// Mapped from the shared 1024 face so the vertical midline matches dock/circle.
func drawMenuBarSymbol(in ctx: CGContext, color: CGColor = black) {
    // Fit the 1024 face into 18pt with equal top/bottom padding (same optical center).
    let faceTop = faceEarY + faceEarR       // 911
    let faceBottom = faceHead.y - faceHeadR // 113
    let faceHeight = faceTop - faceBottom   // 798
    let pad: CGFloat = 1.425
    let scale = (18 - pad * 2) / faceHeight
    let yOf: (CGFloat) -> CGFloat = { pad + ($0 - faceBottom) * scale }
    let xOf: (CGFloat) -> CGFloat = { 9 + ($0 - 512) * scale }

    let earRads = faceEarR * scale
    let headR = faceHeadR * scale

    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setFillColor(color)
    ctx.addEllipse(in: ellipse(CGPoint(x: xOf(faceEarLX), y: yOf(faceEarY)), earRads, earRads))
    ctx.addEllipse(in: ellipse(CGPoint(x: xOf(faceEarRX), y: yOf(faceEarY)), earRads, earRads))
    ctx.addEllipse(in: ellipse(CGPoint(x: xOf(faceHead.x), y: yOf(faceHead.y)), headR, headR))
    ctx.fillPath()
    strokeXs(
        in: ctx,
        left: CGPoint(x: xOf(faceEyeLX), y: yOf(faceEyeY)),
        right: CGPoint(x: xOf(faceEyeRX), y: yOf(faceEyeY)),
        arm: faceEyeArm * scale,
        width: faceEyeWidth * scale
    )
    ctx.endTransparencyLayer()
}

func drawMascotFace(in ctx: CGContext, color: CGColor) {
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setFillColor(color)
    ctx.addEllipse(in: ellipse(CGPoint(x: faceEarLX, y: faceEarY), faceEarR, faceEarR))
    ctx.addEllipse(in: ellipse(CGPoint(x: faceEarRX, y: faceEarY), faceEarR, faceEarR))
    ctx.addEllipse(in: ellipse(faceHead, faceHeadR, faceHeadR))
    ctx.fillPath()
    strokeXs(
        in: ctx,
        left: CGPoint(x: faceEyeLX, y: faceEyeY),
        right: CGPoint(x: faceEyeRX, y: faceEyeY),
        arm: faceEyeArm,
        width: faceEyeWidth
    )
    ctx.endTransparencyLayer()
}

func drawDockFace(in ctx: CGContext, size: CGFloat, circular: Bool = false) {
    ctx.saveGState()
    ctx.scaleBy(x: size / 1024, y: size / 1024)

    let purple = CGColor(red: 0.486, green: 0.165, blue: 0.965, alpha: 1)
    if circular {
        ctx.addEllipse(in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    } else {
        let plate = CGPath(
            roundedRect: CGRect(x: 0, y: 0, width: 1024, height: 1024),
            cornerWidth: 230,
            cornerHeight: 230,
            transform: nil
        )
        ctx.addPath(plate)
    }
    ctx.setFillColor(purple)
    ctx.fillPath()

    drawMascotFace(in: ctx, color: white)
    ctx.restoreGState()
}

func context(size: Int, opaque: Bool = false) -> CGContext {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmap = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    bitmap.interpolationQuality = .high
    bitmap.setAllowsAntialiasing(true)
    bitmap.setShouldAntialias(true)
    if opaque {
        bitmap.setFillColor(CGColor(gray: 1, alpha: 1))
        bitmap.fill(CGRect(x: 0, y: 0, width: size, height: size))
    } else {
        bitmap.clear(CGRect(x: 0, y: 0, width: size, height: size))
    }
    return bitmap
}

func writePNG(_ image: CGImage, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: image)
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: url)
}

func renderMenuPNG() {
    // 54 px is 18 pt at 3x, so the menu bar stays sharp on retina displays.
    writePNG(menuImage(pixelSize: 54), to: resources.appendingPathComponent("MenuBarIcon.png"))
}

func menuImage(pixelSize: Int) -> CGImage {
    let ctx = context(size: pixelSize)
    ctx.scaleBy(x: CGFloat(pixelSize) / 18, y: CGFloat(pixelSize) / 18)
    drawMenuBarSymbol(in: ctx)
    return ctx.makeImage()!
}

func dockImage(pixelSize: Int) -> CGImage {
    let ctx = context(size: pixelSize)
    drawDockFace(in: ctx, size: CGFloat(pixelSize))
    return ctx.makeImage()!
}

func tintedMenu(pixelSize: Int, color: CGColor, background: CGColor) -> CGImage {
    let ctx = context(size: pixelSize)
    ctx.setFillColor(background)
    ctx.fill(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    ctx.saveGState()
    ctx.scaleBy(x: CGFloat(pixelSize) / 18, y: CGFloat(pixelSize) / 18)
    drawMenuBarSymbol(in: ctx, color: color)
    ctx.restoreGState()
    return ctx.makeImage()!
}

func composite(dock: CGImage, background: CGColor) -> CGImage {
    let s = dock.width
    let ctx = context(size: s)
    ctx.setFillColor(background)
    ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))
    ctx.draw(dock, in: CGRect(x: 0, y: 0, width: s, height: s))
    return ctx.makeImage()!
}

renderMenuPNG()

let previews = root.appendingPathComponent("build/icon-previews")
try FileManager.default.createDirectory(at: previews, withIntermediateDirectories: true)

let light = CGColor(red: 0.93, green: 0.93, blue: 0.91, alpha: 1)
let dark = CGColor(red: 0.18, green: 0.18, blue: 0.19, alpha: 1)
let dockLight = CGColor(red: 0.86, green: 0.87, blue: 0.89, alpha: 1)
let dockDark = CGColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1)

writePNG(tintedMenu(pixelSize: 72, color: black, background: light), to: previews.appendingPathComponent("menubar-light.png"))
writePNG(tintedMenu(pixelSize: 72, color: white, background: dark), to: previews.appendingPathComponent("menubar-dark.png"))
writePNG(tintedMenu(pixelSize: 36, color: black, background: light), to: previews.appendingPathComponent("menubar-light-18pt.png"))
writePNG(menuImage(pixelSize: 72), to: previews.appendingPathComponent("menubar-mask.png"))

let dock1024 = dockImage(pixelSize: 1024)
writePNG(dock1024, to: resources.appendingPathComponent("AppIcon-1024.png"))
writePNG(composite(dock: dockImage(pixelSize: 512), background: dockLight), to: previews.appendingPathComponent("dock-light.png"))
writePNG(composite(dock: dockImage(pixelSize: 512), background: dockDark), to: previews.appendingPathComponent("dock-dark.png"))
writePNG(dockImage(pixelSize: 128), to: previews.appendingPathComponent("dock-128.png"))
writePNG(dockImage(pixelSize: 32), to: previews.appendingPathComponent("dock-32.png"))

func circleImage(pixelSize: Int) -> CGImage {
    let ctx = context(size: pixelSize)
    drawDockFace(in: ctx, size: CGFloat(pixelSize), circular: true)
    return ctx.makeImage()!
}

let circle1024 = circleImage(pixelSize: 1024)
writePNG(circle1024, to: resources.appendingPathComponent("logo-circle.png"))
writePNG(circleImage(pixelSize: 256), to: previews.appendingPathComponent("logo-circle-256.png"))

let iconset = previews.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let iconSizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]
for (name, px) in iconSizes {
    writePNG(dockImage(pixelSize: px), to: iconset.appendingPathComponent(name))
}

let icns = resources.appendingPathComponent("AppIcon.icns")
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try proc.run()
proc.waitUntilExit()
if proc.terminationStatus != 0 {
    fputs("iconutil failed\n", stderr)
    exit(1)
}

print("wrote \(resources.path)")
