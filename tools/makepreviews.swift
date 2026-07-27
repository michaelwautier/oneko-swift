import AppKit
import UniformTypeIdentifiers

// Generates animated APNG previews (run-right cycle, 4x nearest-neighbor) for
// every sheet in Resources/, for embedding in the README.
//   swift tools/makepreviews.swift Resources docs/previews

let resourceDir = CommandLine.arguments[1]
let outDir = CommandLine.arguments[2]
try! FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// Run-right frames in the oneko.js sheet layout: (col,row), row 0 at the top.
let runFrames = [(3, 0), (3, 1)]
let scale = 4

for file in try! FileManager.default.contentsOfDirectory(atPath: resourceDir).sorted()
where file.hasSuffix(".png") {
    let sheet = NSImage(contentsOfFile: "\(resourceDir)/\(file)")!
        .cgImage(forProposedRect: nil, context: nil, hints: nil)!
    let cell = sheet.width / 8  // supports @2x sheets too
    let side = cell * scale

    let url = URL(fileURLWithPath: "\(outDir)/\(file)")
    let dest = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, runFrames.count, nil)!
    CGImageDestinationSetProperties(dest,
        [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGLoopCount: 0]] as CFDictionary)

    for (col, row) in runFrames {
        let frame = sheet.cropping(to: CGRect(x: col * cell, y: row * cell,
                                              width: cell, height: cell))!
        let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.interpolationQuality = .none
        ctx.draw(frame, in: CGRect(x: 0, y: 0, width: side, height: side))
        CGImageDestinationAddImage(dest, ctx.makeImage()!,
            [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGDelayTime: 0.25]] as CFDictionary)
    }
    CGImageDestinationFinalize(dest)
    print("wrote \(outDir)/\(file)")
}
