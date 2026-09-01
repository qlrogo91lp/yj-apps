#if os(iOS)
    import CoreGraphics

    /// 카드 캔버스 크기. 값은 pt이고, 픽셀 크기는 `scale`을 곱한 값이다.
    /// 270 × 4 = 1080이라 폰트 크기를 pt로 잡아도 반올림 오차가 생기지 않는다.
    enum ShareCanvas {
        static let scale: CGFloat = 4
        static let width: CGFloat = 270
        static let verticalPadding: CGFloat = 16
        static let rowHeight: CGFloat = 42
        static let logoStripHeight: CGFloat = 32
        static let standaloneHeight: CGFloat = 480

        /// 스티커 캔버스 — 행 수와 로고 유무에 따라 높이가 변한다.
        static func stickerSize(rowCount: Int, hasLogo: Bool) -> CGSize {
            let height = verticalPadding * 2
                + rowHeight * CGFloat(rowCount)
                + (hasLogo ? logoStripHeight : 0)
            return CGSize(width: width, height: height)
        }

        /// 폴백 이미지 캔버스 — 항상 1080×1920 px에 대응한다.
        static let standaloneSize = CGSize(width: width, height: standaloneHeight)
    }
#endif
