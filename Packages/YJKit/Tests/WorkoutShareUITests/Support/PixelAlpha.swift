#if os(iOS)
    import CoreGraphics

    /// 픽셀 하나의 알파. 원본 포맷에 기대지 않도록 RGBA8 컨텍스트에 다시 그려서 읽는다.
    func pixelAlpha(of image: CGImage, x: Int, y: Int) -> UInt8 {
        var pixel = [UInt8](repeating: 0, count: 4)
        pixel.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress,
                                          width: 1, height: 1,
                                          bitsPerComponent: 8, bytesPerRow: 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return }
            // CG 좌표는 아래가 원점 — 위에서 y 번째 픽셀이 (0,0) 에 오게 옮긴다.
            context.draw(image, in: CGRect(x: -x, y: y - image.height + 1,
                                           width: image.width, height: image.height))
        }
        return pixel[3]
    }
#endif
