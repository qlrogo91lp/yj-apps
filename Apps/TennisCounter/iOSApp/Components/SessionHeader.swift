import SwiftUI

/// 세션 하나의 머리 줄 — 날짜(요일) + 누적 운동시간 + 누적 활동 kcal.
///
/// 전적·경기 수는 넣지 않는다. 아래 경기 행을 세면 나오는 값이라, 헤더는 아래에 없는
/// 정보만 갖는 편이 역할이 선명하다.
///
/// **패딩·배경을 스스로 붙이지 않는다.** 카드가 될지 `List` 의 섹션 헤더가 될지는
/// 조립하는 쪽이 정한다 — 여기서 배경을 칠하면 `List` 안에서 이중 배경이 된다.
struct SessionHeader: View {
    let session: MatchSessionGroup

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(Self.dateText(session.date))
                .font(.system(size: 16, weight: .semibold))
            Spacer(minLength: 8)
            Text(verbatim: "\(durationText) · \(caloriesText)")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 누적값이 없는 옛 기록은 "–". 0 으로 흘리지 않는다.
    private var durationText: String {
        session.elapsedSeconds.map(CumulativeDuration.format) ?? "–"
    }

    private var caloriesText: String {
        guard let calories = session.activeCalories else { return "–" }
        return "\(calories.formatted(.number.precision(.fractionLength(0)))) kcal"
    }

    /// "8월 24일 (일)" / "Sat, Aug 24" — 로케일이 순서를 정한다.
    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMdEEE")
        return formatter.string(from: date)
    }
}
