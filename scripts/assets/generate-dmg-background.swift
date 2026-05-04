#!/usr/bin/env swift
// Génère l'image de fond du DMG (600x400 + @2x 1200x800).
// Usage: swift scripts/assets/generate-dmg-background.swift <output.png> [scale]

import AppKit
import CoreGraphics

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "dmg-background.png"
let scale: CGFloat = CommandLine.arguments.count > 2
    ? CGFloat(Double(CommandLine.arguments[2]) ?? 1.0)
    : 1.0

let baseW: CGFloat = 600
let baseH: CGFloat = 400
let w = Int(baseW * scale)
let h = Int(baseH * scale)

guard let context = CGContext(
    data: nil,
    width: w,
    height: h,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

context.scaleBy(x: scale, y: scale)
let rect = CGRect(x: 0, y: 0, width: baseW, height: baseH)

// Fond clair façon macOS, avec un léger dégradé pour de la profondeur.
let bgColors = [
    CGColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0),
    CGColor(red: 0.93, green: 0.93, blue: 0.95, alpha: 1.0)
] as CFArray
let bgGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: bgColors,
    locations: [0, 1]
)!
context.drawLinearGradient(
    bgGradient,
    start: CGPoint(x: 0, y: baseH),
    end: CGPoint(x: 0, y: 0),
    options: []
)

// Flèche horizontale subtile entre les deux icônes (icônes positionnées
// approximativement à x=150 et x=450 dans la fenêtre). On dessine au milieu.
let arrowY = baseH / 2 - 10
let arrowStart: CGFloat = 230
let arrowEnd: CGFloat = 370

context.setStrokeColor(CGColor(red: 0.99, green: 0.49, blue: 0.13, alpha: 0.55))
context.setLineWidth(3)
context.setLineCap(.round)
context.move(to: CGPoint(x: arrowStart, y: arrowY))
context.addLine(to: CGPoint(x: arrowEnd, y: arrowY))
context.strokePath()

// Pointe de flèche
let tipX = arrowEnd
let tipY = arrowY
let headSize: CGFloat = 14
context.setFillColor(CGColor(red: 0.99, green: 0.49, blue: 0.13, alpha: 0.55))
context.move(to: CGPoint(x: tipX, y: tipY))
context.addLine(to: CGPoint(x: tipX - headSize, y: tipY + headSize / 1.6))
context.addLine(to: CGPoint(x: tipX - headSize, y: tipY - headSize / 1.6))
context.closePath()
context.fillPath()

// Texte d'instruction discret
NSGraphicsContext.saveGraphicsState()
let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.current = nsContext

let style = NSMutableParagraphStyle()
style.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 14, weight: .medium),
    .foregroundColor: NSColor(white: 0.4, alpha: 1.0),
    .paragraphStyle: style
]
let text = NSAttributedString(
    string: "Glissez RunBar dans Applications",
    attributes: attrs
)
let textRect = NSRect(x: 0, y: 60, width: baseW, height: 24)
text.draw(in: textRect)
NSGraphicsContext.restoreGraphicsState()

guard let finalImage = context.makeImage() else { exit(1) }
let bitmap = NSBitmapImageRep(cgImage: finalImage)
guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: outputPath))
print("Background written to \(outputPath) (\(w)x\(h))")
