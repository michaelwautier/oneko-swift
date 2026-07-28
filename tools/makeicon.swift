import AppKit

// Builds an .iconset from a small pixel-art glyph: pads it onto a 16x16
// canvas, then integer nearest-neighbor upscales to every icon size.
//   swift tools/makeicon.swift Resources/icons/oneko-icon.png <out.iconset>
// Then: iconutil -c icns <out.iconset> -o Resources/icons/Oneko.icns

let input = CommandLine.arguments[1]
let outDir = CommandLine.arguments[2]
try! FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let src = NSImage(contentsOfFile: input)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let base = 16
let padX = (base - src.width) / 2
let padY = (base - src.height) / 2

func render(_ size: Int, _ name: String) {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .none
    let s = CGFloat(size) / CGFloat(base)
    ctx.draw(src, in: CGRect(x: CGFloat(padX) * s, y: CGFloat(padY) * s,
                             width: CGFloat(src.width) * s, height: CGFloat(src.height) * s))
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}

for size in [16, 32, 128, 256, 512] {
    render(size, "icon_\(size)x\(size)")
    render(size * 2, "icon_\(size)x\(size)@2x")
}
print("wrote \(outDir)")
