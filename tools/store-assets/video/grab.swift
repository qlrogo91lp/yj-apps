import AVFoundation
import ImageIO
import UniformTypeIdentifiers
let url = URL(fileURLWithPath: CommandLine.arguments[1]); let outDir = CommandLine.arguments[2]
let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = .zero
let sem = DispatchSemaphore(value: 0)
Task {
    for t in [0.0, 3.2, 6.0, 7.9] {
        let (img, _) = try await gen.image(at: CMTime(seconds: t, preferredTimescale: 600))
        let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(outDir)/grab-\(t).png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
        print("grab", t, img.width, img.height)
    }
    sem.signal()
}
sem.wait()
