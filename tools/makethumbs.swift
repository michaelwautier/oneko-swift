import AppKit
import UniformTypeIdentifiers

// Generates a static idle-frame thumbnail (4x nearest-neighbor) for every
// sheet in Resources/, for the Raycast extension's skin picker grid.
// Output names use the SpriteVariant rawValue (oneko.png -> cat.png).
//   swift tools/makethumbs.swift Resources raycast/assets/skins

let resourceDir = CommandLine.arguments[1]
let outDir = CommandLine.arguments[2]
try! FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// Idle frame in the oneko.js sheet layout: (col,row), row 0 at the top.
let idle = (3, 3)
let scale = 4

for file in try! FileManager.default.contentsOfDirectory(atPath: resourceDir).sorted()
where file.hasSuffix(".png") {
    let sheet = NSImage(contentsOfFile: "\(resourceDir)/\(file)")!
        .cgImage(forProposedRect: nil, context: nil, hints: nil)!
    let cell = sheet.width / 8  // supports @2x sheets too
    let side = cell * scale

    let outName = file == "oneko.png" ? "cat.png" : file
    let frame = sheet.cropping(to: CGRect(x: idle.0 * cell, y: idle.1 * cell,
                                          width: cell, height: cell))!
    let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .none
    ctx.draw(frame, in: CGRect(x: 0, y: 0, width: side, height: side))

    let url = URL(fileURLWithPath: "\(outDir)/\(outName)")
    let dest = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(outDir)/\(outName)")
}
