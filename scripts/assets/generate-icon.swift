#!/usr/bin/env swift
// Génère un AppIcon placeholder 1024x1024 — fond gradient + "RB" stylisé.
// Usage: swift scripts/assets/generate-icon.swift <output.png>
//
// Remplacer par un vrai design quand disponible.

import AppKit
import CoreGraphics

let size: CGFloat = 1024
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon.png"

guard let context = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

let rect = CGRect(x: 0, y: 0, width: size, height: size)

// Squircle mask façon macOS (~22% corner radius). macOS applique son propre
// masque mais on assure un rendu propre dans Finder/Preview.
let radius: CGFloat = size * 0.2237
let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
context.addPath(path)
context.clip()

// Gradient orange Strava → rouge
let colors = [
    CGColor(red: 0.99, green: 0.49, blue: 0.13, alpha: 1.0),
    CGColor(red: 0.92, green: 0.27, blue: 0.20, alpha: 1.0)
] as CFArray
let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: colors,
    locations: [0, 1]
)!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: size),
    end: CGPoint(x: size, y: 0),
    options: []
)

// Texte "RB" centré, blanc, gras
let nsImage = NSImage(size: NSSize(width: size, height: size))
let cgImage = context.makeImage()!
let rep = NSBitmapImageRep(cgImage: cgImage)
nsImage.addRepresentation(rep)

NSGraphicsContext.saveGraphicsState()
let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.current = nsContext

let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 540, weight: .heavy),
    .foregroundColor: NSColor.white,
    .kern: -20.0
]
let text = NSAttributedString(string: "RB", attributes: attrs)
let textSize = text.size()
let textRect = NSRect(
    x: (size - textSize.width) / 2,
    y: (size - textSize.height) / 2 - 20,
    width: textSize.width,
    height: textSize.height
)
text.draw(in: textRect)
NSGraphicsContext.restoreGraphicsState()

// Export PNG
guard let finalImage = context.makeImage() else { exit(1) }
let bitmap = NSBitmapImageRep(cgImage: finalImage)
guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: outputPath))
print("Icon written to \(outputPath)")
