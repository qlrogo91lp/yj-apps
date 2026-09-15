#if os(iOS)
    import Foundation

    /// 공유 카드 머리줄에 **공유할 때마다** 달라지는 값 — 무슨 운동을 언제 했는지.
    /// 패키지는 종목을 모르므로 제목은 앱이 현지화해서 넘긴다.
    public struct WorkoutShareHeader: Equatable {
        /// "테니스", "골프", "근력" 처럼 앱이 정한 운동 이름.
        public let title: String
        public let startedAt: Date
        /// nil 이면 부제에 시작 시각만 쓴다.
        public let endedAt: Date?

        public init(title: String, startedAt: Date, endedAt: Date?) {
            self.title = title
            self.startedAt = startedAt
            self.endedAt = endedAt
        }
    }
#endif
