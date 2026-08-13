import SwiftUI
import WorkoutCore
import WorkoutUI

/// 세션 가로 3/3 페이지 — 경과시간 · 활동/총 kcal · 심박수 (spec §4).
///
/// WorkoutUI의 공유 화면은 값 타입만 받는다 — 서비스의 현재 값을 스냅샷으로 옮긴다.
/// healthKit은 RoundSessionView의 @StateObject가 소유하고 여기서는 관찰만 하므로
/// computed property로 충분하다. (테니스는 같은 매핑을 ViewModel의 @Published로 뺐는데,
/// 그쪽은 View가 서비스를 소유하지 않아 init에서 매번 새 인스턴스가 만들어지는
/// 함정이 있었기 때문이다. 여기엔 그 함정이 없다.)
struct SessionMetricsView: View {
    @ObservedObject var healthKit: WorkoutSessionService

    var body: some View {
        WorkoutMetricsView(metrics: metrics, isPaused: healthKit.isPaused)
    }

    private var metrics: WorkoutMetrics {
        WorkoutMetrics(elapsedSeconds: TimeInterval(healthKit.elapsedSeconds),
                       activeCalories: healthKit.currentCalories,
                       totalCalories: healthKit.currentCalories + healthKit.currentBasalCalories,
                       heartRate: healthKit.currentHeartRate)
    }
}
