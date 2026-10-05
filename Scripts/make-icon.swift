#!/usr/bin/env swift
// Draws the app icon and writes Resources/AppIcon.icns.
//
//   swift Scripts/make-icon.swift
import AppKit
import Foundation

let canvas: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func drawIcon(in ctx: CGContext) {
    // Background tile, following the macOS icon grid (824pt body on a 1024pt canvas).
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
    ctx.addPath(tilePath)
    ctx.setFillColor(color(0x1E3A5F))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let background = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [color(0x2F6DB5), color(0x1B3A66)] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(background, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])

    // The sheet of paper, slightly rotated.
    ctx.translateBy(x: 512, y: 500)
    ctx.rotate(by: -0.07)
    let sheet = CGRect(x: -235, y: -300, width: 470, height: 600)
    let fold: CGFloat = 110

    let sheetPath = CGMutablePath()
    sheetPath.move(to: CGPoint(x: sheet.minX, y: sheet.minY))
    sheetPath.addLine(to: CGPoint(x: sheet.maxX, y: sheet.minY))
    sheetPath.addLine(to: CGPoint(x: sheet.maxX, y: sheet.maxY - fold))
    sheetPath.addLine(to: CGPoint(x: sheet.maxX - fold, y: sheet.maxY))
    sheetPath.addLine(to: CGPoint(x: sheet.minX, y: sheet.maxY))
    sheetPath.closeSubpath()

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: color(0x000000, 0.4))
    ctx.addPath(sheetPath)
    ctx.setFillColor(color(0xFFFDF6))
    ctx.fillPath()
    ctx.restoreGState()

    // Ruled lines and margin.
    ctx.saveGState()
    ctx.addPath(sheetPath)
    ctx.clip()
    ctx.setLineWidth(6)
    ctx.setStrokeColor(color(0xBFD0E6))
    var y = sheet.maxY - 170
    while y > sheet.minY + 40 {
        ctx.move(to: CGPoint(x: sheet.minX, y: y))
        ctx.addLine(to: CGPoint(x: sheet.maxX, y: y))
        y -= 62
    }
    ctx.strokePath()
    ctx.setStrokeColor(color(0xE5534B, 0.85))
    ctx.move(to: CGPoint(x: sheet.minX + 90, y: sheet.minY))
    ctx.addLine(to: CGPoint(x: sheet.minX + 90, y: sheet.maxY))
    ctx.strokePath()

    // "Index" entries: short dark strokes on the first lines.
    ctx.setLineCap(.round)
    ctx.setLineWidth(18)
    ctx.setStrokeColor(color(0x1E3A5F, 0.85))
    let entries: [CGFloat] = [250, 190, 280, 150]
    for (offset, width) in entries.enumerated() {
        let lineY = sheet.maxY - 170 - CGFloat(offset) * 62 + 22
        ctx.move(to: CGPoint(x: sheet.minX + 130, y: lineY))
        ctx.addLine(to: CGPoint(x: sheet.minX + 130 + width, y: lineY))
    }
    ctx.strokePath()
    ctx.restoreGState()

    // Folded corner.
    let corner = CGMutablePath()
    corner.move(to: CGPoint(x: sheet.maxX - fold, y: sheet.maxY))
    corner.addLine(to: CGPoint(x: sheet.maxX - fold, y: sheet.maxY - fold + 12))
    corner.addQuadCurve(
        to: CGPoint(x: sheet.maxX, y: sheet.maxY - fold),
        control: CGPoint(x: sheet.maxX - fold + 6, y: sheet.maxY - fold + 2)
    )
    corner.closeSubpath()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: -6, height: -6), blur: 14, color: color(0x000000, 0.25))
    ctx.addPath(corner)
    ctx.setFillColor(color(0xE6DFCC))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.restoreGState()
}

func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    let ctx = context.cgContext
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: CGFloat(size) / canvas, y: CGFloat(size) / canvas)
    drawIcon(in: ctx)
    context.flushGraphics()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(filePath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appending(path: "AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    try png(size: points).write(to: iconset.appending(path: "icon_\(points)x\(points).png"))
    try png(size: points * 2).write(to: iconset.appending(path: "icon_\(points)x\(points)@2x.png"))
}

let output = root.appending(path: "Resources/AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(filePath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path(percentEncoded: false), "-o", output.path(percentEncoded: false)]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
try png(size: 1024).write(to: root.appending(path: "Resources/AppIcon.png"))
print("Written \(output.path(percentEncoded: false))")
