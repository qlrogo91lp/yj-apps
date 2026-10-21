#if os(iOS)
    import CoreGraphics

    /// 공유 이미지 캔버스 크기. 값은 pt이고, 픽셀 크기는 `scale`을 곱한 값이다.
    /// 270 × 4 = 1080이라 폰트 크기를 pt로 잡아도 반올림 오차가 생기지 않는다.
    enum ShareCanvas {
        static let scale: CGFloat = 4
        static let cornerRadius: CGFloat = 22

        /// 카드 좌우 안쪽 여백.
        static let horizontalPadding: CGFloat = 18
        /// 카드 안 머리줄 · 자리 · 지표 사이 간격.
        static let stackSpacing: CGFloat = 14

        /// 카드 — 공유 이미지 전체 크기이기도 하다. 칸이 네 개로 고정이라 크기도 하나다.
        /// 헤더 아래 자리를 쓰는 카드는 `cardSize(hasAccessory:)` 가 따로 준다.
        ///
        /// 스토리 화면(1080×1920)으로 구우면 인스타가 배경으로 깔아버린다. 카드만 넘겨야
        /// 사진 한 장으로 받아 옮기고 키울 수 있다.
        static let cardSize = CGSize(width: 270, height: 200)

        /// 헤더 아래 자리 — 앱이 채운다. 폭은 카드 안쪽 폭, 높이는 고정이다.
        /// 내용에 따라 높이가 달라지면 기록마다 스티커 크기가 달라지므로 넘치는 부분은 잘린다.
        static let accessorySize = CGSize(width: cardSize.width - horizontalPadding * 2, height: 30)

        /// 자리를 쓰면 카드가 자리와 간격만큼 높아진다 — 크기는 두 가지뿐이다.
        static func cardSize(hasAccessory: Bool) -> CGSize {
            guard hasAccessory else { return cardSize }
            return CGSize(width: cardSize.width, height: cardSize.height + accessorySize.height + stackSpacing)
        }
    }
#endif
