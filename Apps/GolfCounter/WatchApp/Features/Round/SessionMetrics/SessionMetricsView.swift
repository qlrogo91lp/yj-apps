import SwiftUI
import WorkoutCore
import WorkoutUI

/// 세션 가로 3/3 페이지 — 경과시간 · 활동/총 kcal · 심박수 (spec §4).
///
/// WorkoutUI의 공유 화면은 값 타입만 받는다 — 서비스의 현재 값을 스냅샷으로 옮긴다.
/// healthKit을 `RoundSessionView`의 @StateObject가 소유해 여기서는 관찰만 하므로
/// computed property로 충분하다.
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
