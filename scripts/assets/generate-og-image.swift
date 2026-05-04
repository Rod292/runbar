#!/usr/bin/env swift
// Génère l'OG/Twitter card 1200x630 pour les partages sociaux.
// Usage: swift scripts/assets/generate-og-image.swift <output.png>

import AppKit
import CoreGraphics

let W: CGFloat = 1200
let H: CGFloat = 630
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "og-image.png"

// Charge le logo runner depuis Sources/RunBar/Resources/AppIcon.icns →
// extrait la rep 1024 → la garde pour composite.
let resourcePath = "Sources/RunBar/Resources/AppIcon.icns"
guard let icnsData = NSData(contentsOfFile: resourcePath),
      let icnsRep = NSImage(data: icnsData as Data),
      let bestRep = icnsRep.representations.max(by: { $0.size.width < $1.size.width }) else {
    fputs("Could not load \(resourcePath)\n", stderr)
    exit(1)
}
let logoImage = NSImage()
logoImage.addRepresentation(bestRep)

guard let context = CGContext(
    data: nil,
    width: Int(W),
    height: Int(H),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

NSGraphicsContext.saveGraphicsState()
let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.current = nsContext

// === Fond cream avec léger gradient ===
let bg = [
    CGColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1.0),
    CGColor(red: 0.96, green: 0.94, blue: 0.91, alpha: 1.0)
] as CFArray
let bgGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: bg,
    locations: [0, 1]
)!
context.drawLinearGradient(
    bgGradient,
    start: CGPoint(x: 0, y: H),
    end: CGPoint(x: W, y: 0),
    options: []
)

// === Hairline borders top + bottom ===
context.setStrokeColor(CGColor(red: 0.85, green: 0.83, blue: 0.78, alpha: 1.0))
context.setLineWidth(1)
context.move(to: CGPoint(x: 60, y: H - 60))
context.addLine(to: CGPoint(x: W - 60, y: H - 60))
context.strokePath()
context.move(to: CGPoint(x: 60, y: 60))
context.addLine(to: CGPoint(x: W - 60, y: 60))
context.strokePath()

// === Eyebrow top — mono caps ===
let eyebrowAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .medium),
    .foregroundColor: NSColor(red: 0.45, green: 0.42, blue: 0.38, alpha: 1.0),
    .kern: 4.0
]
NSAttributedString(string: "MENU-BAR APP · macOS 14+", attributes: eyebrowAttrs)
    .draw(at: CGPoint(x: 80, y: H - 95))

// Petit dot vermillon devant l'eyebrow
context.setFillColor(CGColor(red: 0.99, green: 0.36, blue: 0.24, alpha: 1.0))
context.fillEllipse(in: CGRect(x: 60, y: H - 90, width: 8, height: 8))

// === Wordmark "Run·Bar" ===
let runAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "Times New Roman", size: 130)?.italicVariant() ??
           NSFont.systemFont(ofSize: 130, weight: .regular),
    .foregroundColor: NSColor(red: 0.07, green: 0.07, blue: 0.05, alpha: 1.0)
]
let barAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 130, weight: .medium),
    .foregroundColor: NSColor(red: 0.07, green: 0.07, blue: 0.05, alpha: 1.0)
]
let runText = NSAttributedString(string: "Run", attributes: runAttrs)
let barText = NSAttributedString(string: "Bar", attributes: barAttrs)

let runSize = runText.size()
runText.draw(at: CGPoint(x: 80, y: H - 280))
barText.draw(at: CGPoint(x: 80 + runSize.width + 8, y: H - 280))

// Vermillon dot après le wordmark
context.setFillColor(CGColor(red: 0.99, green: 0.36, blue: 0.24, alpha: 1.0))
let dotX = 80 + runSize.width + 8 + barText.size().width + 14
context.fillEllipse(in: CGRect(x: dotX, y: H - 270, width: 18, height: 18))

// === Tagline ===
let taglineAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 36, weight: .regular),
    .foregroundColor: NSColor(red: 0.30, green: 0.28, blue: 0.25, alpha: 1.0)
]
NSAttributedString(string: "A runner in your menu bar.", attributes: taglineAttrs)
    .draw(at: CGPoint(x: 80, y: H - 360))

// === Sub-tagline italic ===
let subAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "Times New Roman", size: 26)?.italicVariant() ??
           NSFont.systemFont(ofSize: 26, weight: .regular),
    .foregroundColor: NSColor(red: 0.40, green: 0.38, blue: 0.34, alpha: 1.0)
]
NSAttributedString(
    string: "Strava tells you what you did.",
    attributes: subAttrs
).draw(at: CGPoint(x: 80, y: H - 425))
NSAttributedString(
    string: "RunBar tells you where you stand — right now.",
    attributes: subAttrs
).draw(at: CGPoint(x: 80, y: H - 462))

// === Bottom mono badges ===
let badgeAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
    .foregroundColor: NSColor(red: 0.50, green: 0.47, blue: 0.43, alpha: 1.0),
    .kern: 2.5
]
NSAttributedString(
    string: "v0.1.2   ·   2.2 MB   ·   STRAVA-SYNCED   ·   FREE",
    attributes: badgeAttrs
).draw(at: CGPoint(x: 80, y: 80))

// === Logo runner sur la droite — avec ombre douce pour le détacher du fond ===
let logoSize: CGFloat = 360
let logoRect = NSRect(
    x: W - logoSize - 110,
    y: (H - logoSize) / 2,
    width: logoSize,
    height: logoSize
)

// Ombre portée — rendu intentionnel "voici l'icône de l'app" plutôt que
// "image qui flotte sur le fond". Trois passes pour un blur naturel.
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor(red: 0.07, green: 0.07, blue: 0.05, alpha: 0.18)
shadow.shadowOffset = NSSize(width: 0, height: -16)
shadow.shadowBlurRadius = 40
shadow.set()
logoImage.draw(in: logoRect, from: .zero, operation: .sourceOver, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()

// === Export ===
guard let finalImage = context.makeImage() else { exit(1) }
let bitmap = NSBitmapImageRep(cgImage: finalImage)
guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: outputPath))
print("OG image written to \(outputPath) (1200×630)")

// MARK: - Helpers

extension NSFont {
    func italicVariant() -> NSFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: self.pointSize) ?? self
    }
}
