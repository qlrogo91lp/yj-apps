#if os(iOS)
    import CoreGraphics

    /// 공유 이미지 캔버스 크기. 값은 pt이고, 픽셀 크기는 `scale`을 곱한 값이다.
    /// 270 × 4 = 1080이라 폰트 크기를 pt로 잡아도 반올림 오차가 생기지 않는다.
    enum ShareCanvas {
        static let scale: CGFloat = 4
        static let width: CGFloat = 270
        static let verticalPadding: CGFloat = 16
        static let rowHeight: CGFloat = 42
        static let logoStripHeight: CGFloat = 32
        static let cornerRadius: CGFloat = 20

        /// 지표 카드 — 공유 이미지 전체 크기이기도 하다. 행 수와 로고 유무에 따라 높이가 변한다.
        ///
        /// 스토리 화면(1080×1920)으로 구우면 인스타가 배경으로 깔아버린다. 카드만 넘겨야
        /// 사진 한 장으로 받아 옮기고 키울 수 있다.
        static func cardSize(rowCount: Int, hasLogo: Bool) -> CGSize {
            let height = verticalPadding * 2
                + rowHeight * CGFloat(rowCount)
                + (hasLogo ? logoStripHeight : 0)
            return CGSize(width: width, height: height)
        }
    }
#endif
