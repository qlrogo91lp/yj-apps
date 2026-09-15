#if os(iOS)
    import UIKit
    import UniformTypeIdentifiers

    /// 구운 카드 이미지를 밖으로 내보내는 방법 두 가지 — 공유 시트용 PNG 파일, 스티커 붙여넣기용 클립보드.
    ///
    /// 둘 다 **PNG** 로 넘긴다. `UIImage` 를 그대로 넘기면 받는 쪽이 JPEG 로 바꿔 둥근 모서리 바깥의
    /// 투명이 검게 찬다.
    enum WorkoutShareExport {
        static func pngData(from image: UIImage) -> Data? {
            image.pngData()
        }

        /// 공유 시트에 넘길 임시 PNG 파일. 탭할 때마다 같은 경로를 덮어쓴다.
        static func pngFile(from image: UIImage) -> URL? {
            guard let data = pngData(from: image) else { return nil }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("workout-share", conformingTo: .png)
            do {
                try data.write(to: url, options: .atomic)
                return url
            } catch {
                return nil
            }
        }

        /// 인스타 스토리에서 화면을 길게 눌러 붙여넣으면 배경 없는 스티커로 올라간다.
        /// Meta App ID 없이 스티커를 만드는 유일한 경로다.
        @discardableResult
        static func copySticker(_ image: UIImage, to pasteboard: UIPasteboard = .general) -> Bool {
            guard let data = pngData(from: image) else { return false }
            pasteboard.setData(data, forPasteboardType: UTType.png.identifier)
            return true
        }
    }
#endif
