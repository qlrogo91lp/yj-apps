// 프레임 PNG 들을 H.264 mp4 로 묶는다. 무음 스테레오 AAC 트랙을 함께 넣는다.
// 사용: swift encode.swift <frames 폴더> <출력.mp4> [fps]
import AVFoundation
import CoreVideo
import Foundation
import ImageIO

let args = CommandLine.arguments
let framesDir = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])
let fps = Int32(args.count > 3 ? Int(args[3])! : 30)

let files = try FileManager.default.contentsOfDirectory(atPath: framesDir.path)
    .filter { $0.hasSuffix(".png") }.sorted()
guard let first = files.first,
      let src0 = CGImageSourceCreateWithURL(framesDir.appendingPathComponent(first) as CFURL, nil),
      let img0 = CGImageSourceCreateImageAtIndex(src0, 0, nil)
else { fatalError("프레임이 없다") }
let width = img0.width, height = img0.height

try? FileManager.default.removeItem(at: outURL)
let writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)

let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 24_000_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoMaxKeyFrameIntervalKey: Int(fps),
        AVVideoExpectedSourceFrameRateKey: Int(fps),
    ],
    AVVideoColorPropertiesKey: [
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
    ],
])
video.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: width,
    kCVPixelBufferHeightKey as String: height,
])
writer.add(video)

let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVNumberOfChannelsKey: 2,
    AVSampleRateKey: 48000,
    AVEncoderBitRateKey: 128_000,
])
audio.expectsMediaDataInRealTime = false
writer.add(audio)

guard writer.startWriting() else { fatalError("startWriting: \(String(describing: writer.error))") }
writer.startSession(atSourceTime: .zero)

let group = DispatchGroup()

// 영상 — 프레임 i 는 i/fps 초
group.enter()
var frameIndex = 0
var videoDone = false
video.requestMediaDataWhenReady(on: DispatchQueue(label: "video")) {
    while video.isReadyForMoreMediaData, !videoDone {
        if frameIndex >= files.count {
            videoDone = true; video.markAsFinished(); group.leave(); return
        }
        let url = framesDir.appendingPathComponent(files[frameIndex])
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil),
              let pool = adaptor.pixelBufferPool
        else { fatalError("읽기 실패 \(files[frameIndex])") }
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
        guard let buf = pb else { fatalError("픽셀 버퍼") }
        CVPixelBufferLockBaseAddress(buf, [])
        let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buf),
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(buf, [])
        if !adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(frameIndex), timescale: fps)) {
            fatalError("append 실패: \(String(describing: writer.error))")
        }
        frameIndex += 1
    }
}

// 무음 — 영상 길이만큼 16bit 스테레오 0
let sampleRate = 48000
let totalSamples = files.count * sampleRate / Int(fps)
var asbd = AudioStreamBasicDescription(mSampleRate: Float64(sampleRate), mFormatID: kAudioFormatLinearPCM,
                                       mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
                                       mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4,
                                       mChannelsPerFrame: 2, mBitsPerChannel: 16, mReserved: 0)
var audioFormat: CMAudioFormatDescription?
CMAudioFormatDescriptionCreate(allocator: nil, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0,
                               magicCookie: nil, extensions: nil, formatDescriptionOut: &audioFormat)
group.enter()
var samplesWritten = 0
var audioDone = false
audio.requestMediaDataWhenReady(on: DispatchQueue(label: "audio")) {
    while audio.isReadyForMoreMediaData, !audioDone {
        if samplesWritten >= totalSamples {
            audioDone = true; audio.markAsFinished(); group.leave(); return
        }
        let n = min(4800, totalSamples - samplesWritten)
        var block: CMBlockBuffer?
        CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: n * 4, blockAllocator: nil,
                                           customBlockSource: nil, offsetToData: 0, dataLength: n * 4,
                                           flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &block)
        CMBlockBufferFillDataBytes(with: 0, blockBuffer: block!, offsetIntoDestination: 0, dataLength: n * 4)
        var sample: CMSampleBuffer?
        CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: block!, formatDescription: audioFormat!,
                                                             sampleCount: n,
                                                             presentationTimeStamp: CMTime(value: CMTimeValue(samplesWritten), timescale: CMTimeScale(sampleRate)),
                                                             packetDescriptions: nil, sampleBufferOut: &sample)
        if !audio.append(sample!) { fatalError("오디오 append 실패: \(String(describing: writer.error))") }
        samplesWritten += n
    }
}

group.wait()
writer.endSession(atSourceTime: CMTime(value: CMTimeValue(files.count), timescale: fps))
let finished = DispatchSemaphore(value: 0)
writer.finishWriting { finished.signal() }
finished.wait()
guard writer.status == .completed else { fatalError("실패: \(String(describing: writer.error))") }

// 검증 — 길이 · 트랙 · 크기 · 프레임레이트 · 용량
let asset = AVURLAsset(url: outURL)
let sem = DispatchSemaphore(value: 0)
Task {
    let duration = try await asset.load(.duration)
    let tracks = try await asset.load(.tracks)
    print("완료", outURL.path)
    print("길이", String(format: "%.3f", duration.seconds), "초 · 프레임", files.count)
    for t in tracks {
        let (size, rate) = try await t.load(.naturalSize, .nominalFrameRate)
        let type = t.mediaType
        print(" 트랙", type.rawValue, type == .video ? "\(Int(size.width))x\(Int(size.height)) @\(rate)fps" : "")
    }
    let bytes = (try FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? NSNumber)?.intValue ?? 0
    print("용량", String(format: "%.1f", Double(bytes) / 1_000_000), "MB")
    sem.signal()
}
sem.wait()
