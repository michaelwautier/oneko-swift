import AppKit

// Builds the app .iconset: the pixel-art glyph, centered by its opaque
// bounding box, integer nearest-neighbor upscaled onto a Catppuccin Mocha
// rounded-rect tile (Apple's 824/1024 icon grid), rendered as a 1024 master
// and downscaled to every iconset size.
//   swift tools/makeicon.swift Resources/icons/oneko-icon.png <out.iconset>
// Then: iconutil -c icns <out.iconset> -o Resources/icons/Oneko.icns

let input = CommandLine.arguments[1]
let outDir = CommandLine.arguments[2]
try! FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let src = NSImage(contentsOfFile: input)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func makeContext(_ size: Int) -> CGContext {
    CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
              space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

// Opaque bounding box (buffer coords, row 0 = top) so the art gets centered,
// not the canvas — the glyph doesn't fill its png symmetrically.
let scan = makeContext(src.width)
scan.draw(src, in: CGRect(x: 0, y: 0, width: src.width, height: src.height))
let buf = scan.data!.assumingMemoryBound(to: UInt8.self)
var minX = src.width, maxX = -1, minY = src.height, maxY = -1
for y in 0..<src.height {
    for x in 0..<src.width where buf[(y * scan.bytesPerRow) + x * 4 + 3] > 0 {
        minX = min(minX, x); maxX = max(maxX, x)
        minY = min(minY, y); maxY = max(maxY, y)
    }
}

// 1024 master: Catppuccin Mocha base (#1e1e2e) tile on Apple's grid,
// glyph at an integer scale.
let master = makeContext(1024)
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
master.addPath(CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil))
master.setFillColor(CGColor(red: 30 / 255, green: 30 / 255, blue: 46 / 255, alpha: 1))
master.fillPath()

let scale = 640 / max(maxX - minX + 1, maxY - minY + 1)  // glyph ~620 px wide
let cx = CGFloat(minX + maxX + 1) / 2                     // bbox center, CG coords
let cy = CGFloat(src.height) - CGFloat(minY + maxY + 1) / 2
master.interpolationQuality = .none
master.draw(src, in: CGRect(x: 512 - cx * CGFloat(scale), y: 512 - cy * CGFloat(scale),
                            width: CGFloat(src.width * scale),
                            height: CGFloat(src.height * scale)))
let masterImage = master.makeImage()!

func render(_ size: Int, _ name: String) {
    let ctx = makeContext(size)
    ctx.interpolationQuality = .high
    ctx.draw(masterImage, in: CGRect(x: 0, y: 0, width: size, height: size))
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}

for size in [16, 32, 128, 256, 512] {
    render(size, "icon_\(size)x\(size)")
    render(size * 2, "icon_\(size)x\(size)@2x")
}
print("wrote \(outDir), glyph bbox \(maxX - minX + 1)x\(maxY - minY + 1) at scale \(scale)")
