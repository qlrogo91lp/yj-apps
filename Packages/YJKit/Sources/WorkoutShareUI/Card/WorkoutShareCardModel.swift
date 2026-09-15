#if os(iOS)
    import Foundation
    import WorkoutCore

    /// 공유 카드에 표시할 머리줄과 2×2 칸. 칸은 네 개로 고정이고, 값이 없으면 "–" 로 둔다 —
    /// 칸을 빼면 기록마다 카드 크기와 배치가 달라진다.
    struct WorkoutShareCardModel: Equatable {
        enum Metric: Equatable {
            case duration
            case activeCalories
            case totalCalories
            case heartRate
        }

        struct Cell: Equatable {
            let metric: Metric
            let value: String
            /// 시간 칸과 값이 없는 칸은 nil — 콜론 포맷이 이미 단위를 담고, "–" 에는 단위가 어색하다.
            let unit: String?
        }

        static let missing = "–"

        let title: String
        /// "9월 9일 · 오후 7:27–오후 10:03"
        let subtitle: String
        let cells: [Cell]

        init(result: WorkoutResult,
             header: WorkoutShareHeader,
             locale: Locale = .current,
             timeZone: TimeZone = .current)
        {
            title = header.title
            subtitle = Self.subtitle(for: header, locale: locale, timeZone: timeZone)
            cells = [
                Cell(metric: .duration, value: WorkoutMetrics.formatSeconds(result.durationSeconds), unit: nil),
                Self.cell(.activeCalories, value: result.caloriesBurned, unit: "KCAL"),
                Self.cell(.totalCalories, value: result.totalCaloriesBurned, unit: "KCAL"),
                Self.cell(.heartRate, value: result.averageHeartRate ?? 0, unit: "BPM"),
            ]
        }

        /// 0 은 "측정 안 됨"으로 본다 — 0 kcal · 0 bpm 운동은 없다.
        private static func cell(_ metric: Metric, value: Double, unit: String) -> Cell {
            guard value > 0 else { return Cell(metric: metric, value: missing, unit: nil) }
            return Cell(metric: metric, value: grouped(value), unit: unit)
        }

        /// 천 단위 콤마. 한국어·영어가 같은 표기라 로케일을 고정해 기기 설정에 흔들리지 않게 한다.
        private static func grouped(_ value: Double) -> String {
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            formatter.roundingMode = .halfUp
            return formatter.string(from: NSNumber(value: value)) ?? String(Int(value.rounded()))
        }

        private static func subtitle(for header: WorkoutShareHeader, locale: Locale, timeZone: TimeZone) -> String {
            let day = DateFormatter()
            day.locale = locale
            day.timeZone = timeZone
            day.setLocalizedDateFormatFromTemplate("MMMd")

            let time = DateFormatter()
            time.locale = locale
            time.timeZone = timeZone
            time.dateStyle = .none
            time.timeStyle = .short

            var range = time.string(from: header.startedAt)
            if let end = header.endedAt {
                range += "–" + time.string(from: end)
            }
            return "\(day.string(from: header.startedAt)) · \(range)"
        }
    }
#endif
