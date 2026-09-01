#if os(iOS)
    import Foundation
    import WorkoutCore

    /// 공유 카드에 표시할 행 목록. 값이 없는 지표는 행 자체를 만들지 않는다.
    struct WorkoutShareCardModel: Equatable {
        enum Metric: Equatable {
            case duration
            case calories
            case heartRate
        }

        struct Row: Equatable {
            let metric: Metric
            let value: String
            /// 시간 행은 nil — 콜론 포맷이 이미 단위를 담고 있다.
            let unit: String?
        }

        let rows: [Row]

        init(result: WorkoutResult) {
            var rows: [Row] = [
                Row(metric: .duration,
                    value: WorkoutMetrics.formatSeconds(result.durationSeconds),
                    unit: nil),
            ]
            if result.caloriesBurned > 0 {
                rows.append(Row(metric: .calories,
                                value: String(format: "%.0f", result.caloriesBurned),
                                unit: "kcal"))
            }
            if let heartRate = result.averageHeartRate, heartRate > 0 {
                rows.append(Row(metric: .heartRate,
                                value: String(format: "%.0f", heartRate),
                                unit: "bpm"))
            }
            self.rows = rows
        }
    }
#endif
