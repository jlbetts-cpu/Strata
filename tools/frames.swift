// Every frame of a screen recording, as numbers and, on request, as pictures.
//
//   swift tools/frames.swift <video.mp4> [--dump <dir> --from <s> --to <s> --every <n>]
//
// Prints one line per decoded frame: its presentation time and how much of the
// screen changed since the frame before (mean absolute difference, 0-255, on a
// 1/8-size greyscale copy). That is a motion trace: a run of non-zero values is
// something moving, its length is how long the motion took on screen, and a
// zero inside a run is a frame the app failed to draw (a hitch) rather than the
// motion ending. `simctl io recordVideo` writes a frame when the screen
// changes, so the gaps between presentation times are also measured.
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count > 1 else { print("usage: frames.swift video [--dump dir --from s --to s --every n]"); exit(1) }
func opt(_ k: String) -> String? { args.firstIndex(of: k).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
let dump = opt("--dump"), from = Double(opt("--from") ?? "0")!, to = Double(opt("--to") ?? "1e9")!
let every = Int(opt("--every") ?? "1")!

let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let track = asset.tracks(withMediaType: .video)[0]
let reader = try! AVAssetReader(asset: asset)
let out = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
reader.add(out); reader.startReading()
if let dump { try? FileManager.default.createDirectory(atPath: dump, withIntermediateDirectories: true) }

var prev: [UInt8]? = nil
var index = 0
while let sample = out.copyNextSampleBuffer() {
    let t = CMSampleBufferGetPresentationTimeStamp(sample).seconds
    guard let buf = CMSampleBufferGetImageBuffer(sample) else { continue }
    CVPixelBufferLockBaseAddress(buf, .readOnly)
    let w = CVPixelBufferGetWidth(buf), h = CVPixelBufferGetHeight(buf), bpr = CVPixelBufferGetBytesPerRow(buf)
    let base = CVPixelBufferGetBaseAddress(buf)!.assumingMemoryBound(to: UInt8.self)
    var grey = [UInt8](); grey.reserveCapacity((w / 8) * (h / 8))
    for y in stride(from: 0, to: h, by: 8) { for x in stride(from: 0, to: w, by: 8) {
        let p = base + y * bpr + x * 4
        grey.append(UInt8((Int(p[0]) + Int(p[1]) * 2 + Int(p[2])) / 4))
    } }
    var diff = 0.0
    if let prev { for i in 0..<min(prev.count, grey.count) { diff += Double(abs(Int(prev[i]) - Int(grey[i]))) }; diff /= Double(grey.count) }
    print(String(format: "%7.3f %6.2f", t, diff))
    prev = grey
    if let dump, t >= from, t <= to, index % every == 0 {
        let ctx = CGContext(data: base, width: w, height: h, bitsPerComponent: 8, bytesPerRow: bpr,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        let img = ctx.makeImage()!
        let url = URL(fileURLWithPath: String(format: "%@/f%07.3f.png", dump, t))
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
    }
    CVPixelBufferUnlockBaseAddress(buf, .readOnly)
    index += 1
}
