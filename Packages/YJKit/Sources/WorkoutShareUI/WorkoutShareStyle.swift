#if os(iOS)
    import SwiftUI

    /// 공유 카드에서 **앱마다** 달라지는 모습 — 머리줄의 원형 로고. 카드 배경·값 색·라벨·배치는 패키지가 소유한다.
    public struct WorkoutShareStyle {
        /// 원형 로고의 배경색. 보통 앱 브랜드 색.
        public let badgeColor: Color
        /// 원 안에 그리는 로고. 템플릿 이미지로 칠한다.
        public let logo: Image
        /// 원 안 로고 색. nil 이면 원 배경 밝기를 보고 검정/흰색을 고른다.
        /// 브랜드 규칙이 따로 있는 앱(골프 — 초록 위 크림색)만 넘긴다.
        public let logoColor: Color?

        public init(badgeColor: Color, logo: Image, logoColor: Color? = nil) {
            self.badgeColor = badgeColor
            self.logo = logo
            self.logoColor = logoColor
        }
    }
#endif
