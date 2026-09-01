#if os(iOS)
    import Testing
    import WorkoutCore
    @testable import WorkoutShareUI

    struct WorkoutShareCardModelTests {
        private func result(duration: Int = 2538,
                            calories: Double = 312,
                            heartRate: Double? = 148) -> WorkoutResult
        {
            WorkoutResult(durationSeconds: duration,
                          caloriesBurned: calories,
                          averageHeartRate: heartRate)
        }

        @Test func includesAllThreeRowsInOrder() {
            let model = WorkoutShareCardModel(result: result())
            #expect(model.rows.map(\.metric) == [.duration, .calories, .heartRate])
        }

        @Test func omitsHeartRateRowWhenMissing() {
            #expect(WorkoutShareCardModel(result: result(heartRate: nil)).rows.map(\.metric)
                == [.duration, .calories])
            #expect(WorkoutShareCardModel(result: result(heartRate: 0)).rows.map(\.metric)
                == [.duration, .calories])
        }

        @Test func omitsCaloriesRowWhenZero() {
            #expect(WorkoutShareCardModel(result: result(calories: 0)).rows.map(\.metric)
                == [.duration, .heartRate])
        }

        @Test func keepsOnlyDurationWhenOthersMissing() {
            let model = WorkoutShareCardModel(result: result(calories: 0, heartRate: nil))
            #expect(model.rows.map(\.metric) == [.duration])
        }

        @Test func formatsDurationUnderOneHour() {
            let model = WorkoutShareCardModel(result: result(duration: 2538))
            #expect(model.rows[0].value == "42:18")
            #expect(model.rows[0].unit == nil)
        }

        @Test func formatsDurationOverOneHourWithHours() {
            let model = WorkoutShareCardModel(result: result(duration: 5400))
            #expect(model.rows[0].value == "1:30:00")
        }

        @Test func roundsCaloriesAndHeartRateToWholeNumbers() {
            let model = WorkoutShareCardModel(result: result(calories: 312.7, heartRate: 147.6))
            #expect(model.rows[1].value == "313")
            #expect(model.rows[1].unit == "kcal")
            #expect(model.rows[2].value == "148")
            #expect(model.rows[2].unit == "bpm")
        }
    }
#endif
