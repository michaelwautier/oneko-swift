import AppKit

// Parses an X11 .xbm (C array, LSB-first bits) into a 32x32 bit grid.
func parseXBM(_ path: String) -> [[Bool]] {
    let text = try! String(contentsOfFile: path, encoding: .utf8)
    var bytes: [UInt8] = []
    var i = text.startIndex
    while let r = text.range(of: "0x", range: i..<text.endIndex) {
        let hexStart = r.upperBound
        var hexEnd = hexStart
        while hexEnd < text.endIndex, text[hexEnd].isHexDigit { hexEnd = text.index(after: hexEnd) }
        if let byte = UInt8(text[hexStart..<hexEnd], radix: 16) { bytes.append(byte) }
        i = hexEnd
    }
    precondition(bytes.count >= 128, "expected 128 bytes in \(path), got \(bytes.count)")
    var grid = [[Bool]](repeating: [Bool](repeating: false, count: 32), count: 32)
    for y in 0..<32 {
        for x in 0..<32 {
            grid[y][x] = (bytes[y * 4 + x / 8] >> (x % 8)) & 1 == 1
        }
    }
    return grid
}

// oneko.js sheet slot (col,row) -> original X11 frame name
let layout: [(Int, Int, String)] = [
    (0,0,"utogi1"), (0,1,"utogi2"),           // scratchWallN
    (1,0,"upleft1"), (1,1,"upleft2"),         // NW
    (2,0,"sleep1"), (2,1,"sleep2"),           // sleeping
    (3,0,"right1"), (3,1,"right2"),           // E
    (4,0,"ltogi1"), (4,1,"ltogi2"),           // scratchWallW
    (5,0,"jare2"), (6,0,"kaki1"), (7,0,"kaki2"), // scratchSelf
    (0,2,"upright1"), (0,3,"upright2"),       // NE
    (1,2,"up1"), (1,3,"up2"),                 // N
    (2,2,"rtogi1"), (2,3,"rtogi2"),           // scratchWallE
    (3,2,"mati3"),                            // tired
    (3,3,"mati2"),                            // idle
    (4,2,"left1"), (4,3,"left2"),             // W
    (5,1,"dwright1"), (5,2,"dwright2"),       // SE
    (5,3,"dwleft1"), (6,1,"dwleft2"),         // SW
    (7,1,"dtogi1"), (6,2,"dtogi2"),           // scratchWallS
    (6,3,"down1"), (7,2,"down2"),             // S
    (7,3,"awake"),                            // alert
]

let root = CommandLine.arguments[1]   // oneko source dir
let animal = CommandLine.arguments[2] // e.g. "dog"
let outPath = CommandLine.arguments[3]

var pixels = [UInt8](repeating: 0, count: 256 * 128 * 4)
for (col, row, frame) in layout {
    let bits = parseXBM("\(root)/bitmaps/\(animal)/\(frame)_\(animal).xbm")
    let mask = parseXBM("\(root)/bitmasks/\(animal)/\(frame)_\(animal)_mask.xbm")
    for y in 0..<32 {
        for x in 0..<32 {
            guard mask[y][x] else { continue }  // transparent
            let v: UInt8 = bits[y][x] ? 0 : 255 // bit set = ink (black)
            let o = ((row * 32 + y) * 256 + col * 32 + x) * 4
            pixels[o] = v; pixels[o+1] = v; pixels[o+2] = v; pixels[o+3] = 255
        }
    }
}

let ctx = CGContext(data: &pixels, width: 256, height: 128, bitsPerComponent: 8,
                    bytesPerRow: 256 * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
