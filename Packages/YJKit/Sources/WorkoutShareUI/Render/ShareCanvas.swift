#if os(iOS)
    import CoreGraphics

    /// 공유 이미지 캔버스 크기. 값은 pt이고, 픽셀 크기는 `scale`을 곱한 값이다.
    /// 270 × 4 = 1080이라 폰트 크기를 pt로 잡아도 반올림 오차가 생기지 않는다.
    enum ShareCanvas {
        static let scale: CGFloat = 4
        static let cornerRadius: CGFloat = 22

        /// 카드 — 공유 이미지 전체 크기이기도 하다. 칸이 네 개로 고정이라 크기도 하나다.
        ///
        /// 스토리 화면(1080×1920)으로 구우면 인스타가 배경으로 깔아버린다. 카드만 넘겨야
        /// 사진 한 장으로 받아 옮기고 키울 수 있다.
        static let cardSize = CGSize(width: 270, height: 200)
    }
#endif
