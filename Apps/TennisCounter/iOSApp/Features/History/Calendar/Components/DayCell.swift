import SwiftUI

/// 점 계산을 뷰에서 떼어 테스트한다.
enum DayCellDots {
    enum Dot: Equatable { case win, loss, more }

    /// 셀 폭이 40pt라 5pt 점 4개 + 간격이 한계다. 넘으면 마지막을 회색 `.more` 로.
    static func dots(for matches: [Match], limit: Int = 4) -> [Dot] {
        let sorted = matches.sorted { $0.startedAt < $1.startedAt }
        if sorted.count <= limit {
            return sorted.map { $0.myTotalSets > $0.yourTotalSets ? .win : .loss }
        }
        return sorted.prefix(limit - 1).map { $0.myTotalSets > $0.yourTotalSets ? .win : .loss } + [.more]
    }
}

struct DayCell: View {
    let date: Date
    let matches: [Match]
    let isSelected: Bool
    let onTap: () -> Void

    private var calendar: Calendar {
        Calendar.current
    }

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(verbatim: "\(calendar.component(.day, from: date))")
                .font(.system(size: 18, weight: isToday || isSelected ? .bold : .semibold))
                .foregroundColor(isSelected ? .black : .primary)
                .frame(width: 40, height: 40)
                // 오늘과 선택은 겹칠 수 있어 채움과 테두리로 나눈다
                .background(Circle().fill(isSelected ? Color.brand : Color.clear))
                .overlay(Circle().strokeBorder(isToday ? Color.brand : Color.clear, lineWidth: 1.5))

            HStack(spacing: 3) {
                ForEach(Array(DayCellDots.dots(for: matches).enumerated()), id: \.offset) { _, dot in
                    Circle()
                        .fill(color(for: dot))
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 5)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private func color(for dot: DayCellDots.Dot) -> Color {
        switch dot {
        case .win: .green
        case .loss: .orange
        case .more: .secondary
        }
    }
}
