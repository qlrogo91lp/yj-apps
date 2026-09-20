import Foundation
@testable import HaruchiFit_Watch_App
import Testing

/// 농도 컷이 **이상/미만**으로 끊기는지, 그리고 **레코드가 있으면 절대 0단계로 떨어지지 않는지**.
///
/// 0단계는 "그날 레코드가 아예 없다" 는 뜻이라 집계 결과에는 나타나지 않는다.
/// 1초짜리 기록이 빈 칸으로 보이면 사용자에겐 "기록이 사라졌다" 가 된다.
struct GrassIntensityTests {
    private func aggregate(seconds: Int, calories: Double? = nil) -> DailyAggregate {
        DailyAggregate(day: Date(timeIntervalSince1970: 0),
                       totalSeconds: seconds,
                       strengthSeconds: seconds,
                       cardioSeconds: 0,
                       totalCalories: calories,
                       sessionCount: 1)
    }

    @Test("29분59초는 1단계 — 30분 컷에 닿지 않았다")
    func justUnderFirstCutIsLight() {
        #expect(GrassIntensity.byTime.level(for: aggregate(seconds: 1799)) == .light)
    }

    @Test("정확히 30분은 2단계 — 경계는 이상/미만이다")
    func exactlyThirtyMinutesIsMedium() {
        #expect(GrassIntensity.byTime.level(for: aggregate(seconds: 1800)) == .medium)
    }

    @Test("정확히 60분은 3단계")
    func exactlySixtyMinutesIsHeavy() {
        #expect(GrassIntensity.byTime.level(for: aggregate(seconds: 3600)) == .heavy)
    }

    @Test("정확히 90분은 4단계")
    func exactlyNinetyMinutesIsPeak() {
        #expect(GrassIntensity.byTime.level(for: aggregate(seconds: 5400)) == .peak)
    }

    @Test("90분을 넘어도 4단계에서 멈춘다")
    func wellOverNinetyStaysPeak() {
        #expect(GrassIntensity.byTime.level(for: aggregate(seconds: 36000)) == .peak)
    }

    @Test("1초짜리 기록도 1단계 — 0단계로 떨어지지 않는다")
    func oneSecondIsStillLight() {
        #expect(GrassIntensity.byTime.level(for: aggregate(seconds: 1)) == .light)
    }

    @Test("기준 값이 0이면 1단계")
    func zeroValueFallsBackToLight() {
        #expect(GrassIntensity.byTime.level(for: aggregate(seconds: 0)) == .light)
    }

    @Test("칼로리 기준에서 값이 없으면 1단계 — 수동 기록이 여기 해당한다")
    func missingCalorieValueFallsBackToLight() {
        let byCalories = GrassIntensity(value: { $0.totalCalories }, cuts: [200, 400, 600])

        #expect(byCalories.level(for: aggregate(seconds: 5400, calories: nil)) == .light)
    }

    @Test("칼로리 기준도 같은 컷 규칙을 쓴다 — 분기가 따로 없다")
    func calorieCutsUseTheSameRule() {
        let byCalories = GrassIntensity(value: { $0.totalCalories }, cuts: [200, 400, 600])

        #expect(byCalories.level(for: aggregate(seconds: 60, calories: 199)) == .light)
        #expect(byCalories.level(for: aggregate(seconds: 60, calories: 200)) == .medium)
        #expect(byCalories.level(for: aggregate(seconds: 60, calories: 600)) == .peak)
    }

    @Test("농도는 크기로 비교된다")
    func levelsAreComparable() {
        #expect(GrassLevel.none < GrassLevel.light)
        #expect(GrassLevel.heavy < GrassLevel.peak)
    }
}
