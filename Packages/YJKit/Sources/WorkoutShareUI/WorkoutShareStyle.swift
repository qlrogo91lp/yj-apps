#if os(iOS)
    import SwiftUI

    /// 공유 카드에서 앱마다 달라지는 부분. 나머지 레이아웃과 문자열은 패키지가 소유한다.
    public struct WorkoutShareStyle {
        /// 카드 배경 그라디언트가 이 색에서 파생된다. 너무 밝은 색은 흰 텍스트와 대비가 떨어진다.
        public let accentColor: Color
        /// nil이면 카드 하단 로고 줄을 통째로 뺀다.
        public let logo: Image?

        public init(accentColor: Color, logo: Image? = nil) {
            self.accentColor = accentColor
            self.logo = logo
        }
    }
#endif
