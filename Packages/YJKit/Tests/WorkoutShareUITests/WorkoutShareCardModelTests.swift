#if os(iOS)
    import Foundation
    import Testing
    import WorkoutCore
    @testable import WorkoutShareUI

    struct WorkoutShareCardModelTests {
        /// 서머타임이 없는 고정 +9 — 기기 시간대와 무관하게 같은 문자열이 나오게.
        private let seoul = TimeZone(secondsFromGMT: 9 * 3600) ?? .gmt
        private let korean = Locale(identifier: "ko_KR")

        private func result(duration: Int = 9351,
                            calories: Double = 1343,
                            total: Double = 1584,
                            heartRate: Double? = 136) -> WorkoutResult
        {
            WorkoutResult(durationSeconds: duration,
                          caloriesBurned: calories,
                          averageHeartRate: heartRate,
                          totalCaloriesBurned: total)
        }

        private func date(_ hour: Int, _ minute: Int) -> Date {
            var components = DateComponents(year: 2026, month: 9, day: 9, hour: hour, minute: minute)
            components.timeZone = seoul
            return Calendar(identifier: .gregorian).date(from: components) ?? .distantPast
        }

        private func model(_ result: WorkoutResult, endedAt: Date?? = nil) -> WorkoutShareCardModel {
            let end: Date? = endedAt ?? date(22, 3)
            return WorkoutShareCardModel(
                result: result,
                header: WorkoutShareHeader(title: "테니스", startedAt: date(19, 27), endedAt: end),
                locale: korean,
                timeZone: seoul
            )
        }

        @Test func alwaysHasFourCellsInFitnessOrder() {
            #expect(model(result()).cells.map(\.metric) == [.duration, .activeCalories, .totalCalories, .heartRate])
        }

        @Test func formatsValuesWithUppercaseUnitsAndGrouping() {
            let cells = model(result()).cells
            #expect(cells[0].value == "2:35:51")
            #expect(cells[0].unit == nil)
            #expect(cells[1].value == "1,343")
            #expect(cells[1].unit == "KCAL")
            #expect(cells[2].value == "1,584")
            #expect(cells[3].value == "136")
            #expect(cells[3].unit == "BPM")
        }

        @Test func roundsToWholeNumbers() {
            let cells = model(result(calories: 312.7, total: 400.2, heartRate: 147.6)).cells
            #expect(cells[1].value == "313")
            #expect(cells[2].value == "400")
            #expect(cells[3].value == "148")
        }

        /// 값이 없어도 칸은 남기고 "–" 로 표시한다 — 카드 크기가 기록마다 달라지지 않게.
        @Test func missingHeartRateShowsDashWithoutUnit() {
            for heartRate in [nil, 0.0] {
                let cell = model(result(heartRate: heartRate)).cells[3]
                #expect(cell.metric == .heartRate)
                #expect(cell.value == "–")
                #expect(cell.unit == nil)
            }
        }

        @Test func zeroCaloriesShowDash() {
            let cells = model(result(calories: 0, total: 0)).cells
            #expect(cells[1].value == "–")
            #expect(cells[2].value == "–")
            #expect(cells.count == 4)
        }

        @Test func titleComesFromHeader() {
            #expect(model(result()).title == "테니스")
        }

        /// 피트니스 앱 머리줄과 같은 모양 — "9월 9일 · 오후 7:27–오후 10:03".
        @Test func subtitleShowsDateAndTimeRange() {
            #expect(model(result()).subtitle == "9월 9일 · 오후 7:27–오후 10:03")
        }

        @Test func subtitleShowsOnlyStartWhenEndMissing() {
            #expect(model(result(), endedAt: .some(nil)).subtitle == "9월 9일 · 오후 7:27")
        }
    }
#endif
